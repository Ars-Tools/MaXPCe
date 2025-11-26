#include"ext.h"
#include"z_dsp.h"
#include<errno.h>
#include<pthread.h>
#include<stdatomic.h>
#include<xpc/xpc.h>
#include<os/lock.h>

// MARK: Helpers

__attribute__((__overloadable__, __always_inline__))
static inline long const xpc_array_parse(xpc_object_t const array, t_atom * __nonnull const argv) {
    __block register long argc = 0;
    xpc_array_apply(array, ^bool(size_t const _, xpc_object_t __nonnull const item) {
        xpc_type_t const type = xpc_get_type(item);
        if ( !type );
        else if ( type == XPC_TYPE_INT64 )
            atom_setlong(argv + argc ++, xpc_int64_get_value(item));
        else if ( type == XPC_TYPE_DOUBLE )
            atom_setfloat(argv + argc ++, xpc_double_get_value(item));
        else if ( type == XPC_TYPE_STRING )
            atom_setsym(argv + argc ++, gensym(xpc_string_get_string_ptr(item)));
        return true;
    });
    return argc;
}

__attribute__((__overloadable__, __always_inline__))
static inline xpc_object_t const xpc_array_create_atom(long const argc, t_atom const*__nonnull const argv) {
    xpc_object_t const arr = xpc_array_create_empty();
    for ( t_atom const*__nonnull arg = argv,*__nonnull const eof = arg + argc ; arg < eof ; ++ arg ) switch ( atom_gettype(arg) ) {
        case A_LONG: {
            xpc_object_t __nonnull const val = xpc_int64_create(atom_getlong(arg));
            xpc_array_append_value(arr, val);
            xpc_release(val);
            break;
        }
        case A_FLOAT: {
            xpc_object_t __nonnull const val = xpc_double_create(atom_getfloat(arg));
            xpc_array_append_value(arr, val);
            xpc_release(val);
            break;
        }
        case A_SYM: {
            xpc_object_t __nonnull const val = xpc_string_create(atom_getsym(arg)->s_name);
            xpc_array_append_value(arr, val);
            xpc_release(val);
            break;
        }
    }
    return arr;
}

// MARK: typedef

typedef struct {
    t_pxobject const super;
    struct { // attribute
        long const quiet;
        long const retry;
        long const delay;
        long const guard;
    } const refer;
    struct {
        os_unfair_lock const ulock;
        xpc_connection_t __nullable proxy;
        
        xpc_object_t __nonnull const store;
    } kr;
    
    struct {
        os_unfair_lock const ulock;
        xpc_connection_t __nullable proxy;
        
        double * __nullable start; // map address
        intptr_t bytes;            // map bytesize
        xpc_object_t __nullable immap; // cursor for input
        xpc_object_t __nullable ommap; // cursor for output
        
        double freqs;   // sampleRate
        intptr_t frame; // vectorSize
        intptr_t cycle; // bufferSize ( ring, per line )
        atomic_intptr_t index;     // elapsed time
        
        struct { // use for guard
            pthread_mutex_t const mutex;
            pthread_cond_t const condv;
            atomic_intptr_t count;
        } guard;
        
    } ar;
    
} t_xpc;

C74_HIDDEN t_class const * class = NULL;

__attribute__((__overloadable__, __always_inline__)) static inline
C74_HIDDEN void out(t_xpc const*const this, xpc_object_t const args) {
    void*__nonnull const outlet = outlet_nth(this, outlet_count(this) - 1);
    xpc_type_t const type = xpc_get_type(args);
    if ( type == XPC_TYPE_NULL )
        outlet_bang(outlet);
    else if ( type == XPC_TYPE_INT64 )
        outlet_int(outlet, xpc_int64_get_value(args));
    else if ( type == XPC_TYPE_DOUBLE )
        outlet_float(outlet, xpc_double_get_value(args));
    else if ( type == XPC_TYPE_STRING )
        outlet_anything(outlet, gensym(xpc_string_get_string_ptr(args)), 0, 0);
    else if ( type == XPC_TYPE_ARRAY ) {
        t_atom * __nonnull const argv = (t_atom*__nonnull const)sysmem_newptr(xpc_array_get_count(args) * sizeof(t_atom const));
        long const argc = xpc_array_parse(args, argv);
        outlet_list(outlet, gensym("list"), argc, argv);
        sysmem_freeptr(argv);
    }
}

__attribute__((__overloadable__, __always_inline__)) static inline
C74_HIDDEN xpc_connection_t __nullable const kr_proxy_retained(t_xpc const*__nonnull const this) {
    os_unfair_lock_lock(&this->kr.ulock);
    xpc_connection_t __nullable const proxy = this->kr.proxy ? xpc_retain(this->kr.proxy) : 0;
    os_unfair_lock_unlock(&this->kr.ulock);
    return proxy;
}

__attribute__((__overloadable__, __always_inline__)) static inline
C74_HIDDEN xpc_connection_t __nullable const kr_proxy_replace(t_xpc*__nonnull const this, xpc_connection_t __nullable const proxy) {
    os_unfair_lock_lock(&this->kr.ulock);
    if ( this->kr.proxy )
        xpc_release(this->kr.proxy);
    this->kr.proxy = proxy;
    os_unfair_lock_unlock(&this->kr.ulock);
}

__attribute__((__overloadable__, __always_inline__)) static inline
C74_HIDDEN xpc_connection_t __nullable const ar_proxy_retained(t_xpc const*__nonnull const this) {
    os_unfair_lock_lock(&this->ar.ulock);
    xpc_connection_t __nullable const proxy = this->ar.proxy ? xpc_retain(this->ar.proxy) : 0;
    os_unfair_lock_unlock(&this->ar.ulock);
    return proxy;
}

__attribute__((__overloadable__, __always_inline__)) static inline
C74_HIDDEN void ar_proxy_replace(t_xpc*__nonnull const this, xpc_connection_t __nullable const proxy) {
    os_unfair_lock_lock(&this->ar.ulock);
    if ( this->ar.proxy )
        xpc_release(this->ar.proxy);
    this->ar.proxy = proxy;
    os_unfair_lock_unlock(&this->ar.ulock);
}

C74_HIDDEN void entry(t_xpc*__nonnull const this, t_symbol const*__nonnull const peer, long const argc, t_atom const*__nonnull const argv) {
    xpc_connection_t __nullable const proxy = kr_proxy_retained(this);
    if ( !proxy ) {
        xpc_connection_t const strap = xpc_connection_create_mach_service(peer->s_name, 0, 0);
        xpc_connection_set_event_handler(strap, ^(xpc_object_t __nonnull const event) {});
        xpc_connection_activate(strap);
        xpc_object_t const req = xpc_dictionary_create_empty();
        xpc_object_t const arg = xpc_array_create_atom(argc, argv);
        xpc_dictionary_set_value(req, "=", arg);
        xpc_object_t const res = xpc_connection_send_message_with_reply_sync(strap, req);
        xpc_object_t const ref = xpc_dictionary_get_value(res, "=");
        if ( xpc_get_type(ref) == XPC_TYPE_ENDPOINT ) {
            xpc_connection_t const kr = xpc_connection_create_from_endpoint(ref);
            xpc_connection_set_event_handler(kr, ^(xpc_object_t __nonnull const event) {
                if ( xpc_get_type(event) == XPC_TYPE_DICTIONARY ) {
                    char const*__nullable const sel = xpc_dictionary_get_string(event, "/");
                    if ( sel ) switch ( *sel ) {
                        case 'n':
                            out(this, xpc_dictionary_get_array(event, "="));
                            break;
                    }
                } else if ( event == XPC_ERROR_CONNECTION_INTERRUPTED ) {
                    if ( this->refer.quiet < 1 )
                        object_warn(this, "remote connection interrupted");
                } else if ( event == XPC_ERROR_CONNECTION_INVALID ) {
                    if ( this->refer.quiet < 1 )
                        object_warn(this, "remote connection invalid");
                    kr_proxy_replace(this, 0);
                }
            });
            xpc_connection_activate(kr);
            
            if ( xpc_dictionary_get_count(this->kr.store) ) {
                xpc_object_t const store = xpc_dictionary_create_empty();
                xpc_dictionary_set_string(store, "/", "d");
                xpc_dictionary_set_value(store, "=", this->kr.store);
                xpc_connection_send_message(kr, store);
                xpc_release(store);
            }
            
            kr_proxy_replace(this, kr);
            
        }
        xpc_release(res);
        xpc_release(arg);
        xpc_release(req);
        xpc_release(strap);
    } else {
        xpc_release(proxy);
    }
    if ( this->refer.retry ) // auto recover
        schedule_defer(this, (method const)entry, this->refer.retry, peer, argc, argv);
}

C74_HIDDEN void del(t_xpc const*__nonnull const this) {
    C74_ASSERT(systhread_ismainthread())
    z_dsp_free(this);
    pthread_cond_destroy(&this->ar.guard.condv);
    pthread_mutex_destroy(&this->ar.guard.mutex);
    if ( this->kr.proxy )
        xpc_release(this->kr.proxy);
    if ( this->ar.proxy )
        xpc_release(this->ar.proxy);
    if ( this->kr.store )
        xpc_release(this->kr.store);
    if ( this->ar.immap )
        xpc_release(this->ar.immap);
    if ( this->ar.ommap )
        xpc_release(this->ar.ommap);
    if ( this->ar.start && this->ar.bytes )
        munmap(this->ar.start, this->ar.bytes);
}

C74_HIDDEN t_xpc const*const new(t_symbol*__nonnull const symbol, long const argc, t_atom const * __nonnull const argv) {
    intptr_t const offset = attr_args_offset(argc, argv);
    if ( offset < 1 ) {
        error("%s less argument", class->c_sym->s_name);
        return 0;
    } else if ( atom_gettype(argv) != A_SYM ) {
        error("%s invalid argument", class->c_sym->s_name);
        return 0;
    } else {
        register t_xpc * object = (t_xpc*const)object_alloc((t_class*const)class);
        *(os_unfair_lock*__nonnull const)&object->kr.ulock = OS_UNFAIR_LOCK_INIT;
        *(os_unfair_lock*__nonnull const)&object->ar.ulock = OS_UNFAIR_LOCK_INIT;
        pthread_mutex_init(&object->ar.guard.mutex, 0);
        pthread_cond_init(&object->ar.guard.condv, 0);
        
        attr_args_process(object, argc - offset, argv + offset);
        outlet_new(object, 0);
        
        *(xpc_object_t __nonnull*__nonnull const)&object->kr.store = xpc_dictionary_create_empty();
        entry(object, atom_getsym(argv), offset, argv);
        
        xpc_object_t __nullable const proxy = kr_proxy_retained(object);
        
        if ( proxy ) {
            xpc_object_t const req = xpc_dictionary_create_empty();
            xpc_dictionary_set_string(req, "/", ":");
            
            xpc_object_t const res = xpc_connection_send_message_with_reply_sync(proxy, req);
            
            z_dsp_setup(object, xpc_dictionary_get_int64(res, "i"));
            ((t_pxobject*__nonnull const)&object->super)->z_misc |= Z_MC_INLETS;
            for ( register intptr_t k = 0, K = xpc_dictionary_get_int64(res, "o") ; k < K ; ++ k )
                outlet_new(object, "multichannelsignal");
            
            xpc_release(res);
            xpc_release(req);
            xpc_release(proxy);
            
            return object;
        } else {
            object_error(object, "connection is not established");
            del(object);
            return 0;
        }
        
    }
}
C74_HIDDEN void assist(t_xpc const*const this, void const*const _, long const scope, long const index, char * string) {
    xpc_object_t __nullable const proxy = kr_proxy_retained(this);
    if ( proxy ) {
        xpc_object_t const req = xpc_dictionary_create_empty();
        xpc_dictionary_set_string(req, "/", "?");
        xpc_dictionary_set_int64(req, "#", index);
        switch (scope) {
            case ASSIST_INLET:
                xpc_dictionary_set_bool(req, ":", false);
                break;
            case ASSIST_OUTLET:
                xpc_dictionary_set_bool(req, ":", true);
                break;
        }
        xpc_object_t const res = xpc_connection_send_message_with_reply_sync(proxy, req);
        xpc_object_t const sym = xpc_dictionary_get_value(res, "=");
        if ( xpc_get_type(sym) == XPC_TYPE_STRING )
            strncpy(string, xpc_string_get_string_ptr(sym), ASSIST_MAX_STRING_LEN);
        xpc_release(res);
        xpc_release(req);
        xpc_release(proxy);
    }
}
C74_HIDDEN void dblclick(t_xpc const*__nonnull const this) {
    intptr_t const len = 4096;
    char * __nonnull const msg = sysmem_newptrclear(len);
    xpc_connection_t __nullable const kr = kr_proxy_retained(this);
    sprintf(msg, "connection: %s\r\n", kr ? "OK" : "NO");
    xpc_release(kr);
    xpc_dictionary_apply(this->kr.store, ^bool(char const * __nonnull const key, xpc_object_t __nonnull const value) {
        char reg[64];
        if ( !value );
        else if ( xpc_get_type(value) == XPC_TYPE_INT64 )
            snprintf(reg, sizeof(reg), "%s: %lld\r\n", key, xpc_int64_get_value(value));
        else if ( xpc_get_type(value) == XPC_TYPE_DOUBLE )
            snprintf(reg, sizeof(reg), "%s: %lf\r\n", key, xpc_double_get_value(value));
        else if ( xpc_get_type(value) == XPC_TYPE_STRING )
            snprintf(reg, sizeof(reg), "%s: %s\r\n", key, xpc_string_get_string_ptr(value));
        strncat(msg, reg, len - strnlen(msg, len) - 1);
        return true;
    });
    object_post(this, "%s", msg);
    sysmem_freeptr(msg);
}
C74_HIDDEN long input(t_xpc const*const this, long const index, long const count) {
    xpc_object_t __nullable const proxy = kr_proxy_retained(this);
    if ( proxy ) {
        xpc_object_t const req = xpc_dictionary_create_empty();
        xpc_dictionary_set_string(req, "/", "<");
        xpc_dictionary_set_int64(req, "#", index);
        xpc_dictionary_set_int64(req, "=", count);
        xpc_object_t const res = xpc_connection_send_message_with_reply_sync(proxy, req);
        long const val = xpc_dictionary_get_int64(res, "=");
        xpc_release(res);
        xpc_release(req);
        xpc_release(proxy);
        return val;
    } else {
        return 0;
    }
}
C74_HIDDEN long output(t_xpc const*const this, long const index) {
    xpc_object_t __nullable const proxy = kr_proxy_retained(this);
    if ( proxy ) {
        xpc_object_t const req = xpc_dictionary_create_empty();
        xpc_dictionary_set_string(req, "/", ">");
        xpc_dictionary_set_int64(req, "#", index);
        xpc_object_t const res = xpc_connection_send_message_with_reply_sync(proxy, req);
        long const val = xpc_dictionary_get_int64(res, "=");
        xpc_release(res);
        xpc_release(req);
        xpc_release(proxy);
        return val;
    } else {
        return 1; // fail-safe
    }
}

__attribute__((__overloadable__)) static inline
C74_HIDDEN void req(t_xpc const*__nonnull const this, void(^setup)(xpc_object_t __nonnull const)) {
    xpc_connection_t const proxy = kr_proxy_retained(this);
    if ( proxy ) {
        xpc_object_t const req = xpc_dictionary_create_empty();
        setup(req);
        xpc_connection_send_message(proxy, req);
        xpc_connection_send_message_with_reply(proxy, req, 0, ^(xpc_object_t __nonnull const res) {
            if ( xpc_get_type(res) == XPC_TYPE_DICTIONARY )
                out(this, xpc_dictionary_get_value(res, "="));
        });
        xpc_release(req);
        xpc_release(proxy);
    }
}

C74_HIDDEN void fixnum(t_xpc const*const this, long const value) {
    req(this, ^(xpc_object_t __nonnull const req) {
        xpc_dictionary_set_string(req, "/", "i");
        xpc_dictionary_set_int64(req, "#", proxy_getinlet(this));
        xpc_dictionary_set_int64(req, "=", value);
    });
}
C74_HIDDEN void fltnum(t_xpc const*const this, double const value) {
    req(this, ^(xpc_object_t __nonnull const req) {
        xpc_dictionary_set_string(req, "/", "f");
        xpc_dictionary_set_int64(req, "#", proxy_getinlet(this));
        xpc_dictionary_set_double(req, "=", value);
    });
}
C74_HIDDEN void symbol(t_xpc const*const this, t_symbol const * __nonnull const value) {
    req(this, ^(xpc_object_t __nonnull const req) {
        xpc_dictionary_set_string(req, "/", "s");
        xpc_dictionary_set_int64(req, "#", proxy_getinlet(this));
        xpc_dictionary_set_string(req, "=", value->s_name);
    });
}
C74_HIDDEN void bang(t_xpc const*const this) {
    req(this, ^(xpc_object_t __nonnull const req) {
        xpc_dictionary_set_string(req, "/", "b");
        xpc_dictionary_set_int64(req, "#", proxy_getinlet(this));
    });
}
C74_HIDDEN void list(t_xpc const*const this, t_symbol*__nonnull const msg, intptr_t const argc, t_atom const*__nonnull const argv) {
    req(this, ^(xpc_object_t __nonnull const req) {
        xpc_object_t const arg = xpc_array_create_atom(argc, argv);
        xpc_dictionary_set_string(req, "/", "l");
        xpc_dictionary_set_int64(req, "#", proxy_getinlet(this));
        xpc_dictionary_set_value(req, "=", arg);
        xpc_release(arg);
    });
}
C74_HIDDEN void set(t_xpc const*const this, t_symbol*__nonnull const msg, intptr_t const argc, t_atom const*__nonnull const argv) {
    switch ( argc ) {
        case 2:
            switch ( atom_gettype(argv+0) ) {
                case A_SYM: {
                    switch ( atom_gettype(argv+1) ) {
                        case A_SYM:
                            xpc_dictionary_set_string(this->kr.store, atom_getsym(argv+0)->s_name, atom_getsym(argv+1)->s_name);
                            req(this, ^(xpc_object_t __nonnull const req) {
                                xpc_object_t const arg = xpc_array_create_atom(argc, argv);
                                xpc_dictionary_set_string(req, "/", "p");
                                xpc_dictionary_set_string(req, "k", atom_getsym(argv+0)->s_name);
                                xpc_dictionary_set_string(req, "v", atom_getsym(argv+1)->s_name);
                                xpc_release(arg);
                            });
                            break;
                        case A_LONG:
                            xpc_dictionary_set_int64(this->kr.store, atom_getsym(argv+0)->s_name, atom_getlong(argv+1));
                            req(this, ^(xpc_object_t __nonnull const req) {
                                xpc_object_t const arg = xpc_array_create_atom(argc, argv);
                                xpc_dictionary_set_string(req, "/", "p");
                                xpc_dictionary_set_string(req, "k", atom_getsym(argv+0)->s_name);
                                xpc_dictionary_set_int64(req, "v", atom_getlong(argv+1));
                                xpc_release(arg);
                            });
                            break;
                        case A_FLOAT:
                            xpc_dictionary_set_double(this->kr.store, atom_getsym(argv+0)->s_name, atom_getfloat(argv+1));
                            req(this, ^(xpc_object_t __nonnull const req) {
                                xpc_object_t const arg = xpc_array_create_atom(argc, argv);
                                xpc_dictionary_set_string(req, "/", "p");
                                xpc_dictionary_set_string(req, "k", atom_getsym(argv+0)->s_name);
                                xpc_dictionary_set_double(req, "v", atom_getfloat(argv+1));
                                xpc_release(arg);
                            });
                            break;
                    }
                    return;
                }
            }
        default:
            object_warn(this, "set [key] [value]");
            break;
    }
}
__attribute__((__overloadable__))
C74_HIDDEN void setup(t_xpc*const this) {
    xpc_connection_t __nullable const proxy = kr_proxy_retained(this);
    if ( proxy ) {
        xpc_object_t const mem = xpc_shmem_create(this->ar.start, this->ar.bytes);
        xpc_object_t const req = xpc_dictionary_create_empty();
        xpc_dictionary_set_string(req, "/", "&");
        xpc_dictionary_set_double(req, "s", this->ar.freqs); // sample rate
        xpc_dictionary_set_int64(req, "c", this->ar.frame);  // vector size (max)
        xpc_dictionary_set_value(req, "m", mem); // shared memory
        xpc_dictionary_set_int64(req, "n", this->ar.cycle); //
        xpc_dictionary_set_value(req, "i", this->ar.immap); // offset input
        xpc_dictionary_set_value(req, "o", this->ar.ommap); // offset output
        xpc_object_t const res = xpc_connection_send_message_with_reply_sync(proxy, req);
        xpc_object_t const ref = xpc_dictionary_get_value(res, "=");
        if ( xpc_get_type(ref) == XPC_TYPE_ENDPOINT ) {
            xpc_connection_t const synth = xpc_connection_create_from_endpoint(ref);
            xpc_connection_set_event_handler(synth, ^(xpc_object_t __nonnull const event) {
                if ( xpc_get_type(event) == XPC_TYPE_DICTIONARY ) {
                    
                } else if ( event == XPC_ERROR_CONNECTION_INTERRUPTED ) {
                    if ( this->refer.quiet < 1 )
                        object_warn(this, "dsp connection interrupted");
                } else if ( event == XPC_ERROR_CONNECTION_INVALID ) {
                    if ( this->refer.quiet < 1 )
                        object_warn(this, "dsp connection invalid");
                    ar_proxy_replace(this, 0);
                }
            });
            xpc_connection_activate(synth);
            
            if ( this->refer.guard ) {
                pthread_mutex_lock(&this->ar.guard.mutex);
                atomic_store_explicit(&this->ar.guard.count, this->ar.cycle, memory_order_release);
                pthread_cond_signal(&this->ar.guard.condv);
                pthread_mutex_unlock(&this->ar.guard.mutex);
            }
            
            atomic_store_explicit(&this->ar.index, 0, memory_order_release);
            ar_proxy_replace(this, synth);
            
        }
        xpc_release(mem);
        xpc_release(res);
        xpc_release(req);
        xpc_release(proxy);
    } else {
        ar_proxy_replace(this, 0);
    }
}
C74_HIDDEN void synth(t_xpc*const this, xpc_connection_t const proxy,
                      double const*const*const im, long const ic,
                      double      *const*const om, long const oc,
                      intptr_t const start, intptr_t const count) {
    // enque
    {
        register intptr_t const size = this->ar.cycle;
        register intptr_t const base = ( start + this->refer.delay ) % size;
        register intptr_t const head = MIN(count, size - base);
        register intptr_t const tail = MAX(0, base + count - size);
        xpc_array_apply(this->ar.immap, ^bool(size_t const index, xpc_object_t __nonnull const value) {
            C74_ASSERT(xpc_get_type(value) == XPC_TYPE_INT64)
            register double * __nonnull const mem = this->ar.start + xpc_int64_get_value(value);
            memcpy(mem + base, im[index], head * sizeof(double const));
            memcpy(mem, im[index] + head, tail * sizeof(double const));
            return index < ic;
        });
    }
    {
        xpc_object_t const req = xpc_dictionary_create_empty();
        xpc_dictionary_set_int64(req, "s", start);
        xpc_dictionary_set_int64(req, "c", count);
        xpc_dictionary_set_int64(req, "i", ic);
        xpc_dictionary_set_int64(req, "o", oc);
        xpc_object_t const res = xpc_connection_send_message_with_reply_sync(proxy, req);
        xpc_release(req);
        xpc_release(res);
    }
    {
        register intptr_t const size = this->ar.cycle;
        register intptr_t const base = ( start ) % size;
        register intptr_t const head = MIN(count, size - base);
        register intptr_t const tail = MAX(0, base + count - size);
        xpc_array_apply(this->ar.ommap, ^bool(size_t const index, xpc_object_t __nonnull const value) {
            C74_ASSERT(xpc_get_type(value) == XPC_TYPE_INT64)
            register double * __nonnull const mem = this->ar.start + xpc_int64_get_value(value);
            memcpy(om[index], mem + base, head * sizeof(double const));
            memcpy(om[index] + head, mem, tail * sizeof(double const));
            return index < oc;
        });
    }
}
C74_HIDDEN void async(t_xpc*const this, xpc_connection_t const proxy,
                      double const*const*const im, long const ic,
                      double      *const*const om, long const oc,
                      intptr_t const start, intptr_t const count) {
    {
        register intptr_t const size = this->ar.cycle;
        register intptr_t const base = ( start ) % size;
        register intptr_t const head = MIN(count, size - base);
        register intptr_t const tail = MAX(0, base + count - size);
        xpc_array_apply(this->ar.immap, ^bool(size_t const index, xpc_object_t __nonnull const value) {
            C74_ASSERT(xpc_get_type(value) == XPC_TYPE_INT64)
            register double * __nonnull const mem = this->ar.start + xpc_int64_get_value(value);
            memcpy(mem + base, im[index], head * sizeof(double const));
            memcpy(mem, im[index] + head, tail * sizeof(double const));
            return index < ic;
        });
    }
    {
        register intptr_t const size = this->ar.cycle;
        register intptr_t const base = ( start + size - this->refer.delay ) % size;
        register intptr_t const head = MIN(count, size - base);
        register intptr_t const tail = MAX(0, base + count - size);
        xpc_array_apply(this->ar.ommap, ^bool(size_t const index, xpc_object_t __nonnull const value) {
            C74_ASSERT(xpc_get_type(value) == XPC_TYPE_INT64)
            register double * __nonnull const mem = this->ar.start + xpc_int64_get_value(value);
            memcpy(om[index], mem + base, head * sizeof(double const));
            memcpy(om[index] + head, mem, tail * sizeof(double const));
            return index < oc;
        });
    }
    { // order synth
        xpc_object_t const req = xpc_dictionary_create_empty();
        xpc_dictionary_set_int64(req, "s", start);
        xpc_dictionary_set_int64(req, "c", count);
        xpc_dictionary_set_int64(req, "i", ic);
        xpc_dictionary_set_int64(req, "o", oc);
        xpc_connection_send_message(proxy, req);
        xpc_release(req);
    }
}
C74_HIDDEN void guard(t_xpc*const this, xpc_connection_t const proxy,
                      double const*const*const im, long const ic,
                      double      *const*const om, long const oc,
                      intptr_t const start, intptr_t const count) {
    { // guard available sample
        pthread_mutex_lock(&this->ar.guard.mutex);
        while ( atomic_load_explicit(&this->ar.guard.count, memory_order_acquire) < count )
            if ( pthread_cond_timedwait_relative_np(&this->ar.guard.condv, &this->ar.guard.mutex, &(struct timespec) {
                .tv_sec=0,
                .tv_nsec=NSEC_PER_SEC/(this->ar.freqs/(count*this->refer.guard))
            }) ) {
                if ( this->refer.quiet < 1 )
                    object_error(this, "xpc dsp timedout, wider vector size might be better");
                break;
            }
        atomic_fetch_sub_explicit(&this->ar.guard.count, count, memory_order_acq_rel);
        pthread_mutex_unlock(&this->ar.guard.mutex);
    }
    {
        register intptr_t const size = this->ar.cycle;
        register intptr_t const base = ( start ) % size;
        register intptr_t const head = MIN(count, size - base);
        register intptr_t const tail = MAX(0, base + count - size);
        xpc_array_apply(this->ar.immap, ^bool(size_t const index, xpc_object_t __nonnull const value) {
            C74_ASSERT(xpc_get_type(value) == XPC_TYPE_INT64)
            register double * __nonnull const mem = this->ar.start + xpc_int64_get_value(value);
            memcpy(mem + base, im[index], head * sizeof(double const));
            memcpy(mem, im[index] + head, tail * sizeof(double const));
            return index < ic;
        });
    }
    {
        register intptr_t const size = this->ar.cycle;
        register intptr_t const base = ( start + size - this->refer.delay ) % size;
        register intptr_t const head = MIN(count, size - base);
        register intptr_t const tail = MAX(0, base + count - size);
        xpc_array_apply(this->ar.ommap, ^bool(size_t const index, xpc_object_t __nonnull const value) {
            C74_ASSERT(xpc_get_type(value) == XPC_TYPE_INT64)
            register double * __nonnull const mem = this->ar.start + xpc_int64_get_value(value);
            memcpy(om[index], mem + base, head * sizeof(double const));
            memcpy(om[index] + head, mem, tail * sizeof(double const));
            return index < oc;
        });
    }
    { // order synth
        xpc_object_t const req = xpc_dictionary_create_empty();
        xpc_dictionary_set_int64(req, "s", start);
        xpc_dictionary_set_int64(req, "c", count);
        xpc_dictionary_set_int64(req, "i", ic);
        xpc_dictionary_set_int64(req, "o", oc);
        xpc_connection_send_message_with_reply(proxy, req, 0, ^(xpc_object_t __nonnull const res) {
            pthread_mutex_lock(&this->ar.guard.mutex);
            atomic_fetch_add_explicit(&this->ar.guard.count, count, memory_order_acq_rel);
            pthread_cond_signal(&this->ar.guard.condv);
            pthread_mutex_unlock(&this->ar.guard.mutex);
        });
        xpc_release(req);
    }
}
C74_HIDDEN void routine64(t_xpc*const this, t_object const*const dsp64,
                          double const*const*const im, long const ic,
                          double      *const*const om, long const oc,
                          long const count, long const flags,
                          void const*const parameter) {
    C74_ASSERT(systhread_isaudiothread())
    intptr_t const start = atomic_fetch_add_explicit(&this->ar.index, count, memory_order_acq_rel);
    // xpc is not ready
    
    xpc_connection_t __nullable const ar = ar_proxy_retained(this);
    if ( ar ) {
        ((void(*)(t_xpc*const, xpc_connection_t const,
                  double const*const*const, long const,
                  double      *const*const, long const,
                  intptr_t const, intptr_t const))parameter)(this, ar,
                                                             im, ic,
                                                             om, oc,
                                                             start, count);
        xpc_release(ar);
    } else {
        setup(this);
        for ( register double*__nonnull const*__nonnull k = om, *__nonnull const* __nonnull const K = k + oc ; k < K ; ++ k )
            memset(*k, 0, count * sizeof(double const));
    }
}
C74_HIDDEN void dsp64(t_xpc*const this, t_object const*const dsp64, long const*const count, double const sampleRate, long const vectorSize, long const flags) {
    C74_ASSERT(systhread_ismainthread())
    
    this->ar.freqs = sampleRate;
    this->ar.cycle = ( this->ar.frame = vectorSize ) + this->refer.delay; // in sample
    
    if ( this->ar.start )
        munmap(this->ar.start, this->ar.bytes);
    this->ar.bytes = 0;
    {
        register t_symbol const * __nonnull const msg = gensym("getnuminputchannels");
        if ( this->ar.immap )
            xpc_release(this->ar.immap);
        this->ar.immap = xpc_array_create_empty();
        for ( register intptr_t j = 0, J = inlet_count(this) - 0 ; j < J ; ++ j )
            for ( register intptr_t k = 0, K = object_method(dsp64, msg, this, j) ; k < K ; ++ k, this->ar.bytes += this->ar.cycle )
                xpc_array_append_value(this->ar.immap, xpc_int64_create(this->ar.bytes));
    }
    {
        register t_symbol const * __nonnull const msg = gensym("getnumoutputchannels");
        if ( this->ar.ommap )
            xpc_release(this->ar.ommap);
        this->ar.ommap = xpc_array_create_empty();
        for ( register intptr_t j = 0, J = outlet_count(this) - 1 ; j < J ; ++ j )
            for ( register intptr_t k = 0, K = object_method(dsp64, msg, this, j) ; k < K ; ++ k, this->ar.bytes += this->ar.cycle )
                xpc_array_append_value(this->ar.ommap, xpc_int64_create(this->ar.bytes));
    }
    
    this->ar.start = this->ar.bytes ?
    mmap(0, this->ar.bytes *= sizeof(double const), PROT_READ|PROT_WRITE, MAP_SHARED|MAP_ANONYMOUS, -1, 0) : NULL;
    
    // aggressive setup
    setup(this);
    
    // register
    dsp_add64((t_object*const)dsp64,
              (t_object*const)this,
              (t_perfroutine64 const)routine64,
              0,
              this->ar.cycle < 2 * vectorSize ?
              (t_perfroutine64 const)synth : this->refer.guard ?
              (t_perfroutine64 const)guard :
              (t_perfroutine64 const)async);
}
C74_EXPORT void ext_main(void*const _) {
    if (!class) {
        //
        t_class * const object = (t_class*const)class_new("mc.xpc~", (method const)new, (method const)del, sizeof(t_xpc const), 0L, A_GIMME, 0);
        
        // MSG
        class_addmethod(object, (method const)bang, "bang", 0);
        class_addmethod(object, (method const)list, "list", A_GIMME, 0);
        class_addmethod(object, (method const)set, "set", A_GIMME, 0);
        class_addmethod(object, (method const)fixnum, "int", A_LONG, 0);
        class_addmethod(object, (method const)fltnum, "float", A_FLOAT, 0);
        
        // DSP
        class_addmethod(object, (method const)dsp64, "dsp64", A_CANT, 0);
                
        // Attr
        class_addattr(object, attr_offset_new("quiet", gensym("long"), 0, (method const)0, (method const)0, offsetof(t_xpc, refer.quiet)));
        class_addattr(object, attr_offset_new("retry", gensym("long"), 0, (method const)0, (method const)0, offsetof(t_xpc, refer.retry)));
        class_addattr(object, attr_offset_new("delay", gensym("long"), 0, (method const)0, (method const)0, offsetof(t_xpc, refer.delay)));
        class_addattr(object, attr_offset_new("guard", gensym("long"), 0, (method const)0, (method const)0, offsetof(t_xpc, refer.guard)));
        
        // Assist
        class_addmethod(object, (method const)assist, "assist", A_CANT, 0);
        class_addmethod(object, (method const)dblclick, "dblclick", A_CANT, 0);
        class_addmethod(object, (method const)input, "inputchanged", A_CANT, 0);
        class_addmethod(object, (method const)output, "multichanneloutputs", A_CANT, 0);
        
        // DSP Initialisation
        class_dspinit(object);
        
        // Register
        class_register(CLASS_BOX, class = object);
    }
}
