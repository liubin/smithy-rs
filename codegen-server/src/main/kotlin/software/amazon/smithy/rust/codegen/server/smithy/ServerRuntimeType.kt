/*
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0.
 */

package software.amazon.smithy.rust.codegen.server.smithy

import software.amazon.smithy.rust.codegen.rustlang.CargoDependency
import software.amazon.smithy.rust.codegen.rustlang.InlineDependency
import software.amazon.smithy.rust.codegen.smithy.RuntimeConfig
import software.amazon.smithy.rust.codegen.smithy.RuntimeType

/**
 * Object used *exclusively* in the runtime of the server, for separation concerns.
 * Analogous to the companion object in [RuntimeType]; see its documentation for details.
 * For a runtime type that is used in the client, or in both the client and the server, use [RuntimeType] directly.
 */
object ServerRuntimeType {
    fun forInlineDependency(inlineDependency: InlineDependency) =
        RuntimeType(inlineDependency.name, inlineDependency, namespace = "crate")

    val Phantom = RuntimeType("PhantomData", dependency = null, namespace = "std::marker")
    val Cow = RuntimeType("Cow", dependency = null, namespace = "std::borrow")

    fun Router(runtimeConfig: RuntimeConfig) =
        RuntimeType("Router", CargoDependency.SmithyHttpServer(runtimeConfig), "${runtimeConfig.crateSrcPrefix}_http_server::routing")

    fun RequestSpecModule(runtimeConfig: RuntimeConfig) =
        RuntimeType("request_spec", CargoDependency.SmithyHttpServer(runtimeConfig), "${runtimeConfig.crateSrcPrefix}_http_server::routing")

    fun serverOperationHandler(runtimeConfig: RuntimeConfig) =
        forInlineDependency(ServerInlineDependency.serverOperationHandler(runtimeConfig))

    fun RuntimeError(runtimeConfig: RuntimeConfig) =
        RuntimeType("RuntimeError", CargoDependency.SmithyHttpServer(runtimeConfig), "${runtimeConfig.crateSrcPrefix}_http_server::runtime_error")

    fun RequestRejection(runtimeConfig: RuntimeConfig) =
        RuntimeType("RequestRejection", CargoDependency.SmithyHttpServer(runtimeConfig), "${runtimeConfig.crateSrcPrefix}_http_server::rejection")

    fun ResponseRejection(runtimeConfig: RuntimeConfig) =
        RuntimeType("ResponseRejection", CargoDependency.SmithyHttpServer(runtimeConfig), "${runtimeConfig.crateSrcPrefix}_http_server::rejection")
}
