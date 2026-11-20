//
//  lib.c
//  MaXPCe
//
//  Created by Kota on 11/20/26.
//
#include"ext.h"
#include<os/log.h>
#include<simd/simd.h>
#include<CoreFoundation/CoreFoundation.h>

C74_HIDDEN static t_class const * class = NULL;

extern void * core_new(CFArrayRef __nonnull const, void(^notifier)(CFArrayRef __nonnull const));
extern void core_del(void*__nonnull const);
extern void core_bang(void*__nonnull const);
extern void core_integer(void*__nonnull const, int64_t const);
extern void core_floatingpoint(void*__nonnull const, float64_t const);
extern void core_list(void*__nonnull const, CFArrayRef __nonnull const);
extern void core_anything(void*__nonnull const, CFArrayRef __nonnull const, void(^response)(CFArrayRef __nonnull const));

typedef struct {
    t_object const super;
    void * __nonnull const refer;
} core_t;

C74_HIDDEN CFMutableArrayRef __nonnull inline static const __array__(long const argc, t_atom const * _Nullable const argv) {
    CFMutableArrayRef const object = CFArrayCreateMutable(kCFAllocatorDefault, argc, 0);
    for ( t_atom const * it = argv, * const _ = it + argc ; it < _ ; ++ it ) switch ( it->a_type ) {
        case A_LONG:
            CFArrayAppendValue(object, CFNumberCreate(kCFAllocatorDefault, kCFNumberLongType, &it->a_w.w_long));
            break;
        case A_FLOAT:
            CFArrayAppendValue(object, CFNumberCreate(kCFAllocatorDefault, kCFNumberDoubleType, &it->a_w.w_float));
            break;
        case A_SYM:
            CFArrayAppendValue(object, CFStringCreateWithCString(kCFAllocatorDefault, atom_getsym(it)->s_name, CFStringGetSystemEncoding()));
            break;
    }
    return object;
}
C74_HIDDEN intptr_t inline static const __parse__(CFArrayRef __nonnull const array, t_atom * __nonnull const list) {
    intptr_t done = 0;
    for ( intptr_t k = 0, K = CFArrayGetCount(array) ; k < K ; ++ k ) {
        CFTypeRef const value = CFArrayGetValueAtIndex(array, k);
        if ( CFGetTypeID(value) == CFStringGetTypeID() )
            atom_setsym(list + done ++ , gensym(CFStringGetCStringPtr(value, CFStringGetSystemEncoding())));
        else if ( CFGetTypeID(value) == CFNumberGetTypeID() ) {
            if ( CFNumberIsFloatType(value) ) {
                double number;
                CFNumberGetValue(value, kCFNumberDoubleType, &number);
                atom_setfloat(list + done ++, number);
            } else {
                long number;
                CFNumberGetValue(value, kCFNumberLongType, &number);
                atom_setlong(list + done ++, number);
            }
        }
    }
    return done;
}
C74_HIDDEN void __bang__(core_t const * __nonnull const this) {
    core_bang(this->refer);
}
C74_HIDDEN void __integer__(core_t const * __nonnull const this, t_atom_long const value) {
    core_integer(this->refer, value);
}
C74_HIDDEN void __floatingpoint___(core_t const * __nonnull const this, double const value) {
    core_floatingpoint(this->refer, value);
}
C74_HIDDEN void __list__(core_t const * __nonnull const this, t_symbol * const _, long const argc, t_atom const * __nonnull const argv) {
    CFMutableArrayRef __nonnull const list = __array__(argc, argv);
    core_list(this->refer, list);
    CFRelease(list);
}
C74_HIDDEN void __out__(core_t const * __nonnull const this, t_symbol const * __nonnull const msg, short const argc, t_atom const * _Nullable const argv) {
    outlet_anything(outlet_nth(this, 0), msg, argc, argv);
}
C74_HIDDEN void __anything__(core_t const * __nonnull const this, t_symbol * const sym, long const argc, t_atom const * __nonnull const argv) {
    CFMutableArrayRef __nonnull const list = __array__(argc, argv);
    core_anything(this->refer, list, ^(CFArrayRef  _Nonnull const array) {
        t_atom * __nonnull const list = sysmem_newptr(CFArrayGetCount(array) * sizeof(t_atom const));
        defer_low(this, (method const)__out__, sym, __parse__(array, list), list);
        sysmem_freeptr(list);
    });
    CFRelease(list);
}
C74_HIDDEN void __del__(core_t const * __nonnull const this) {
    core_del(this->refer);
}
C74_HIDDEN core_t const * __nullable const __new__(t_symbol * const name, long const argc, t_atom const * _Nullable const argv) {
    core_t * __nullable const object = object_alloc(class);
    if ( object ) {
        outlet_new(object, "anything");
        CFMutableArrayRef __nonnull const args = __array__(argc, argv);
        *__builtin_bit_cast(void*__nonnull*__nonnull const, &object->refer) = core_new(args, ^(CFArrayRef _Nonnull const args) {
            t_atom*__nonnull const list = __builtin_bit_cast(t_atom*__nonnull const, sysmem_newptr(CFArrayGetCount(args) * sizeof(t_atom const)));
            sysmem_freeptr(list);
        });
        CFRelease(args);
    }
    return object;
}
C74_EXPORT void ext_main(void * const _) {
    if ((class = class_new("max", (method const)__new__, (method const)__del__, sizeof(core_t const), 0, A_GIMME, 0))) {
        class_addmethod((t_class*const)class, (method const)__bang__, "bang", 0);
        class_addmethod((t_class*const)class, (method const)__integer__, "int", A_LONG, 0);
        class_addmethod((t_class*const)class, (method const)__floatingpoint___, "float", A_FLOAT, 0);
        class_addmethod((t_class*const)class, (method const)__list__, "list", A_GIMME, 0);
        class_addmethod((t_class*const)class, (method const)__anything__, "anything", A_GIMME, 0);
        class_register(CLASS_BOX, (t_class*const)class);
    }
}
