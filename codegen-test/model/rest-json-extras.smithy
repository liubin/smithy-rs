$version: "1.0"

namespace aws.protocoltests.restjson

use aws.protocols#restJson1
use aws.api#service
use smithy.test#httpRequestTests
use smithy.test#httpResponseTests

// TODO(https://github.com/awslabs/smithy/pull/1049): Remove this once the test case in Smithy is fixed
apply InputAndOutputWithHeaders @httpResponseTests([
    {
        id: "FIXED_RestJsonInputAndOutputWithQuotedStringHeaders",
        documentation: "Tests responses with string list header bindings that require quoting",
        protocol: restJson1,
        code: 200,
        headers: {
            "X-StringList": "\"b,c\", \"\\\"def\\\"\", a"
        },
        params: {
            headerStringList: ["b,c", "\"def\"", "a"]
        }
    }
])

// TODO(https://github.com/awslabs/smithy/pull/1042): Remove this once the test case in Smithy is fixed
apply PostPlayerAction @httpRequestTests([
    {
        id: "FIXED_RestJsonInputUnionWithUnitMember",
        documentation: "Unit types in unions are serialized like normal structures in requests.",
        protocol: restJson1,
        method: "POST",
        "uri": "/PostPlayerInput",
        body: """
            {
                "action": {
                    "quit": {}
                }
            }""",
        bodyMediaType: "application/json",
        headers: {"Content-Type": "application/json"},
        params: {
            action: {
                quit: {}
            }
        }
    }
])

apply QueryPrecedence @httpRequestTests([
    {
        id: "UrlParamsKeyEncoding",
        documentation: "Keys and values must be url encoded",
        protocol: restJson1,
        method: "POST",
        uri: "/Precedence",
        body: "",
        queryParams: ["bar=%26%F0%9F%90%B1", "hello%20there=how%27s%20your%20encoding%3F", "a%20%26%20b%20%26%20c=better%20encode%20%3D%20this"],
        params: {
            foo: "&🐱",
            baz: {
                "hello there": "how's your encoding?",
                "a & b & c": "better encode = this"
            }
        },
        appliesTo: "client",
    },
    {
        id: "RestJsonQueryPrecedenceForbid",
        documentation: "Prefer named query parameters when serializing",
        protocol: restJson1,
        method: "POST",
        uri: "/Precedence",
        body: "",
        queryParams: [
            "bar=named",
            "qux=alsoFromMap"
        ],
        forbidQueryParams: ["bar=fromMap"],
        params: {
            foo: "named",
            baz: {
                bar: "fromMap",
                qux: "alsoFromMap"
            }
        },
        appliesTo: "client",
    }]
)

/// A REST JSON service that sends JSON requests and responses.
@service(sdkId: "Rest Json Protocol")
@restJson1
service RestJsonExtras {
    version: "2019-12-16",
    operations: [
        StringPayload,
        PrimitiveIntHeader,
        EnumQuery,
        StatusResponse,
        MapWithEnumKeyOp,
        PrimitiveIntOp,
        EscapedStringValues,
        NullInNonSparse,
        CaseInsensitiveErrorOperation,
        EmptyStructWithContentOnWireOp,
        // TODO(https://github.com/awslabs/smithy/pull/1042): Remove this once the test case in Smithy is fixed
        PostPlayerAction
    ],
    errors: [ExtraError]
}

@httpResponseTests([
    {
        documentation: "Upper case error modeled lower case",
        id: "ServiceLevelError",
        protocol: "aws.protocols#restJson1",
        code: 500,
        body: "",
        headers: { "X-Amzn-Errortype": "ExtraError" },
        params: {}
    }
])
@error("server")
@error("server")
structure ExtraError {}

@http(uri: "/StringPayload", method: "POST")
@httpRequestTests([
    {
        id: "StringPayload",
        uri: "/StringPayload",
        body: "rawstring",
        params: { payload: "rawstring" },
        method: "POST",
        protocol: "aws.protocols#restJson1"
    }
])
operation StringPayload {
    input: StringPayloadInput,
    output: StringPayloadInput
}

structure StringPayloadInput {
    @httpPayload
    payload: String
}

@httpRequestTests([{
    id: "SerPrimitiveInt",
    protocol: "aws.protocols#restJson1",
    documentation: "Primitive ints should not be serialized when they are unset",
    uri: "/primitive-document",
    method: "POST",
    body: "{}",
    params: {}
}])
@http(uri: "/primitive-document", method: "POST")
operation PrimitiveIntOp {
    input: PrimitiveIntDocument,
    output: PrimitiveIntDocument
}

structure PrimitiveIntDocument {
    value: PrimitiveInt
}

@httpResponseTests([
    {
        id: "DeserPrimitiveHeader",
        protocol: "aws.protocols#restJson1",
        code: 200,
        headers: { "x-field": "123" },
        params: { field: 123 }
    },
    {
        id: "DeserPrimitiveHeaderMissing",
        protocol: "aws.protocols#restJson1",
        code: 200,
        headers: { },
        params: { field: 0 }
    }
])
@http(uri: "/primitive", method: "POST")
operation PrimitiveIntHeader {
    output: PrimitiveIntHeaderInput
}

integer PrimitiveInt

structure PrimitiveIntHeaderInput {
    @httpHeader("x-field")
    @required
    field: PrimitiveInt
}

@http(uri: "/foo/{enum}", method: "GET")
@httpRequestTests([
    {
        id: "EnumQueryRequest",
        uri: "/foo/enumvalue",
        params: { enum: "enumvalue" },
        method: "GET",
        protocol: "aws.protocols#restJson1"
    }
])
operation EnumQuery {
    input: EnumQueryInput
}

structure EnumQueryInput {
    @httpLabel
    @required
    enum: StringEnum
}

@http(uri: "/", method: "POST")
operation StatusResponse {
    output: StatusOutput
}

structure StatusOutput {
    @httpResponseCode
    field: PrimitiveInt
}

map MapWithEnumKey {
    key: StringEnum,
    value: String,
}

structure MapWithEnumKeyInputOutput {
    map: MapWithEnumKey,
}

@http(uri: "/map-with-enum-key", method: "POST")
@httpRequestTests([
    {
        id: "MapWithEnumKeyRequest",
        uri: "/map-with-enum-key",
        method: "POST",
        protocol: "aws.protocols#restJson1",
        body: "{\"map\":{\"enumvalue\":\"something\"}}",
        params: { map: { "enumvalue": "something" } }
    },
])
@httpResponseTests([
    {
        id: "MapWithEnumKeyResponse",
        protocol: "aws.protocols#restJson1",
        code: 200,
        body: "{\"map\":{\"enumvalue\":\"something\"}}",
        params: { map: { "enumvalue": "something" } },
    },
])
operation MapWithEnumKeyOp {
    input: MapWithEnumKeyInputOutput,
    output: MapWithEnumKeyInputOutput,
}


@enum([
    { value: "has\"quotes", name: "HAS_QUOTES", documentation: "this needs#tobe escaped" },
    { value: "normal", name: "NORMAL" },
])
string EnumWithEscapedChars

structure EscapedStringValuesInputOutput {
    enum: EnumWithEscapedChars,
    @jsonName("also\"has\"quotes")
    someString: String,
}

@http(uri: "/escaped-string-values", method: "POST")
@httpRequestTests([
    {
        id: "EscapedStringValuesRequest",
        uri: "/escaped-string-values",
        method: "POST",
        protocol: "aws.protocols#restJson1",
        body: "{\"enum\":\"has\\\"quotes\",\"also\\\"has\\\"quotes\":\"test\"}",
        params: { enum: "has\"quotes", someString: "test" },
    }
])
@httpResponseTests([
    {
        id: "EscapedStringValuesResponse",
        protocol: "aws.protocols#restJson1",
        code: 200,
        body: "{\"enum\":\"has\\\"quotes\",\"also\\\"has\\\"quotes\":\"test\"}",
        params: { enum: "has\"quotes", someString: "test" },
    }
])
operation EscapedStringValues {
    input: EscapedStringValuesInputOutput,
    output: EscapedStringValuesInputOutput,
}

list NonSparseList {
    member: String,
}

map NonSparseMap {
    key: String,
    value: String,
}

union SingleElementUnion {
    a: String
}

structure NullInNonSparseOutput {
    list: NonSparseList,
    map: NonSparseMap,
    union: SingleElementUnion
}

@http(uri: "/null-in-non-sparse", method: "POST")
@httpResponseTests([
    {
        id: "NullInNonSparse",
        protocol: "aws.protocols#restJson1",
        code: 200,
        body: "{\"list\":[null,\"one\",null,\"two\",null],\"map\":{\"zero\":null,\"one\":\"1\"}}",
        params: { list: ["one", "two"], map: { "one": "1" } },
    }
])
operation NullInNonSparse {
    output: NullInNonSparseOutput,
}

@http(uri: "/error-sensitive", method: "POST")
operation CaseInsensitiveErrorOperation {
    errors: [CaseInsensitiveError]
}

@httpResponseTests([
    {
        documentation: "Upper case error modeled lower case",
        id: "UpperErrorModeledLower",
        protocol: "aws.protocols#restJson1",
        code: 500,
        body: "{\"Message\": \"hello\"}",
        headers: { "X-Amzn-Errortype": "CaseInsensitiveError" },
        params: { message: "hello" }
    }
])
@error("server")
structure CaseInsensitiveError {
    message: String
}

structure EmptyStruct {}
structure EmptyStructWithContentOnWireOpOutput {
    empty: EmptyStruct,
}

@http(uri: "/empty-struct-with-content-on-wire-op", method: "GET")
@httpResponseTests([
    {
        id: "EmptyStructWithContentOnWire",
        protocol: "aws.protocols#restJson1",
        code: 200,
        body: "{\"empty\": {\"value\":\"not actually empty\"}}",
        params: { empty: {} }
    }
])
operation EmptyStructWithContentOnWireOp {
    output: EmptyStructWithContentOnWireOpOutput,
}
