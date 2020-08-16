module Json.Decode.Field exposing (require, requireAt, optional, optionalAt, attempt, attemptAt)

{-| # Decode JSON objects

Since JSON values are not known until runtime there is no way
of checking them at compile time. This means that there is a
possibility a decoding operation can not be successfully completed.

In that case there are two possible solutions:

1. Fail the whole decoding operation.
2. Deal with the missing value situation, either by defaulting to some value or by
   using a `Maybe` value

In this module these two options are represented by `require`, `optional`, and
`attempt`.

* `require` fails if either the field is missing or is the wrong type.
* `optional` succeeds with a `Nothing` if field is missing, but fails if the
  field exists and is the wrong type.
* `attempt` always succeeds with a `Maybe` value.

@docs require, requireAt, optional, optionalAt, attempt, attemptAt

-}

import Json.Decode as Decode exposing (Decoder)


{-| Decode required fields.

Example:

    import Json.Decode as Decode exposing (Decoder)

    user : Decoder User
    user =
        require "id" Decode.int <| \id ->
        require "name" Decode.string <| \name ->

        Decode.succeed
            { id = id
            , name = name
            }

In this example the decoder will fail if:

* The JSON value is not an object.
* Any of the fields `"id"` or `"name"` are missing. If the object contains other fields
  they are ignored and will not cause the decoder to fail.
* The value of field `"id"` is not an `Int`.
* The value of field `"name"` is not a `String`.

-}
require : String -> Decoder a -> (a -> Decoder b) -> Decoder b
require fieldName valueDecoder continuation =
    Decode.field fieldName valueDecoder
        |> Decode.andThen continuation


{-| Decode required nested fields. Works the same as `require` but on nested fieds.

    import Json.Decode as Decode exposing (Decoder)

    blogPost : Decoder BlogPost
    blogPost =
        require "id" Decode.int <| \id ->
        require "title" Decode.string <| \title ->
        requireAt ["author", "name"] Decode.string <| \authorName ->

        Decode.succeed
            { id = id
            , title = title
            , author = authorName
            }
-}
requireAt : List String -> Decoder a -> (a -> Decoder b) -> Decoder b
requireAt path valueDecoder continuation =
    Decode.at path valueDecoder
        |> Decode.andThen continuation


{-| Decode optional fields.

If the decode succeeds you get a `Just value`. If the field is missing you get
a `Nothing`.

Example:

    import Json.Decode as Decode exposing (Decoder)

    name : Decoder Name
    name =
        require "first" Decode.string <| \first ->
        optional "middle" Decode.string <| \maybeMiddle ->
        require "last" Decode.string <| \last ->

        Decode.succeed
            { first = first
            , middle = Maybe.withDefault "" middle
            , last = last
            }

The outcomes of this example are:

* If the JSON value is not an object the decoder will fail.
* If the value of field `"middle"` is a string, `maybeMiddle` will be `Just string`
* If the value of field `"middle"` is something else, the decoder will fail.
* If the field `"middle"` is missing, `maybeMiddle` will be `Nothing`

Note that optional is not the same as nullable. If a field must exist but can
be null, use [`require`](#require) and
[`Decode.nullable`](https://package.elm-lang.org/packages/elm/json/latest/Json-Decode#nullable)
instead:

    require "field" (Decode.nullable Decode.string) <| \field ->

If a field is both optional and nullable [`attempt`](#attempt) is a better
option than using `optional` with `Decode.nullable`, as `attempt` gives you a
`Maybe a` compared to the `Maybe (Maybe a)` that `optional` with `nullable`
would give:

    attempt "field" Decode.string <| \maybeField ->

-}
optional : String -> Decoder a -> (Maybe a -> Decoder b) -> Decoder b
optional fieldName valueDecoder continuation =
    attempt fieldName Decode.value <| \value ->
    case value of
        Just _ ->
            require fieldName valueDecoder (Decode.succeed << Just)
                |> Decode.andThen continuation

        Nothing ->
            continuation Nothing


{-| Decode optional nested fields. Works the same was as `optional` but on nested fields.

-}
optionalAt : List String -> Decoder a -> (Maybe a -> Decoder b) -> Decoder b
optionalAt path valueDecoder continuation =
    attemptAt path Decode.value <| \value ->
    case value of
        Just _ ->
            requireAt path valueDecoder (Decode.succeed << Just)
                |> Decode.andThen continuation

        Nothing ->
            continuation Nothing


{-| Decode fields that may fail.

Always decodes to a `Maybe` value and never fails.

Example:

    import Json.Decode as Decode exposing (Decoder)

    person : Decoder Person
    person =
        require "name" Decode.string <| \name ->
        attempt "weight" Decode.int <| \maybeWeight ->

        Decode.succeed
            { name = name
            , weight = maybeWeight
            }

In this example the `maybeWeight` value will be `Nothing` if:

* The JSON value was not an object
* The `weight` field is missing.
* The `weight` field is not an `Int`.

In this case there is no difference between a field being `null` or missing.

-}
attempt : String -> Decoder a -> (Maybe a -> Decoder b) -> Decoder b
attempt fieldName valueDecoder continuation =
    Decode.maybe (Decode.field fieldName valueDecoder)
        |> Decode.andThen continuation


{-| Decode nested fields that may fail. Works the same way as `attempt` but on nested fields.

-}
attemptAt : List String -> Decoder a -> (Maybe a -> Decoder b) -> Decoder b
attemptAt path valueDecoder continuation =
    Decode.maybe (Decode.at path valueDecoder)
        |> Decode.andThen continuation
