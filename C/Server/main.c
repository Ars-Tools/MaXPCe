//
//  main.c
//  MaXPCe
//
//  Created by Kota on 11/26/25.
//

#include<stdio.h>
#include<dispatch/dispatch.h>
#include<xpc/xpc.h>
#include"mxo.h"
xpc_endpoint_t const kr(xpc_object_t const args) {
    xpc_connection_t const express = xpc_connection_create(0, 0);
    xpc_connection_set_event_handler(express, ^(xpc_object_t __nonnull const client) {
        if ( xpc_get_type(client) == XPC_TYPE_CONNECTION ) {
            xpc_set_event_stream_handler(client, 0, ^(xpc_object_t __nonnull const object) {
                if ( xpc_get_type(object) == XPC_TYPE_DICTIONARY ) {
                    char const * const s = xpc_dictionary_get_string(object, "/");
                    if ( s ) switch ( *s ) {
                        case '/':
                            break;
                    }
                }
            });
            xpc_connection_resume(client);
        }
    });
    xpc_connection_set_context(express, express);
    xpc_connection_resume(express);
    return xpc_endpoint_create(express);
}
int main(int argc, char**argv) {
    xpc_connection_t const ingress = xpc_connection_create_mach_service("xpc.server", 0, XPC_CONNECTION_MACH_SERVICE_LISTENER);
    xpc_connection_set_event_handler(ingress, ^(xpc_object_t __nonnull const client) {
        if ( xpc_get_type(client) == XPC_TYPE_CONNECTION ) {
            xpc_set_event_stream_handler(client, 0, ^(xpc_object_t __nonnull const object) {
                if ( xpc_get_type(object) == XPC_TYPE_DICTIONARY ) {
                    xpc_object_t const a = xpc_dictionary_get_value(object, "=");
                    xpc_object_t const p = xpc_dictionary_get_remote_connection(object);
                    xpc_object_t const r = xpc_dictionary_create_reply(object);
                    xpc_dictionary_set_value(r, "=", kr(a));
                    xpc_connection_send_message(object, r);
                }
            });
            xpc_connection_resume(client);
        }
    });
    xpc_connection_resume(ingress);
    dispatch_main();
    return 0;
}
