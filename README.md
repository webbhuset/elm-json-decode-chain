# Continuation-passing style JSON decoder in Elm

This packages helps you writing JSON decoders in a [Continuation-passing](https://en.wikipedia.org/wiki/Continuation-passing_style) style.
This enables you to use named bindings for field names which is very useful when
decoding JSON objects to Elm records or custom types.


* [Introduction](#introduction)
* [Examples](#examples)
    * [Combine Fields](#combine-fields)
    * [Nested JSON Objects](#nested-json-objects)
    * [Fail decoder if values are invalid](#fail-decoder-if-values-are-invalid)
    * [Decode custom types](#decode-custom-types)
* [How does this work?](#how-does-this-work)

## Introduction

Let's say you have a `Person` record in Elm with the following requirements:

```elm
type alias Person =
    { id : Int -- Field is mandatory, decoder should fail if field is missing in the JSON object
    , name : String -- Field is mandatory
    , maybeWeight : Maybe Int -- Field is optional in the JSON object
    , likes : Int -- Should default to 0 if JSON field is missing or null
    , hardcoded : String -- Should be hardcoded to "Hardcoded Value" for now
    }
```
The approach [suggested by the core JSON library](https://package.elm-lang.org/packages/elm/json/latest/Json-Decode#map3) is to use the `Json.Decode.mapN` family of decoders to build
a record.

```elm
import Json.Decode as Decode exposing (Decoder)

person : Decoder Person
person =
    Decode.map5 Person
        (Decode.field "id" Decode.int)
        (Decode.field "name" Decode.string)
        (Decode.maybe <| Decode.field "weight" Decode.int)
        (Decode.field "likes" Decode.int
            |> Decode.maybe
            |> Decode.map (Maybe.withDefault 0)
        )
        (Decode.succeed "Hardcoded Value")
```

Using this package you can write the same decoder like this:

```elm
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Field as Field

person : Decoder Person
person =
    Field.require "name" Decode.string <| \name ->
    Field.require "id" Decode.int <| \id ->
    Field.optional "weight" Decode.int <| \maybeWeight ->
    Field.attempt "likes" Decode.int <| \maybeLikes ->

    Decode.succeed
        { name = name
        , id = id
        , maybeWeight = maybeWeight
        , likes = Maybe.withDefault 0 maybeLikes
        , hardcoded = "Hardcoded Value"
        }
```

The main advantages over using `mapN` are:

* Record field order does not matter. Named bindings are used instead of field order.
  You can change the order of the fields in the type declaration (`type alias Person ...`) without breaking the decoder.
* Easier to see how the record is connected to the JSON object - especially when there are many fields.
  Sometimes the JSON fields have different names than your Elm record.
* Easier to add fields down the line.
* With the `mapN` approach, if all fields of the record are of the same type and you mess up the field order, you
  won't get any compiler error. Things will appear OK but field values will be transposed.
  Since this package uses named bindings it is much easier to get things right.
* Sometimes fields needs futher validation / processing. See below examples.
* If you have more than 8 fields in your object you can't use the `Json.Decode.mapN` approach since
  [map8](https://package.elm-lang.org/packages/elm/json/latest/Json-Decode#map8) is the largest map function.

## Examples

### Combine fields

In this example the JSON object contains both `firstname` and `lastname`, but the Elm record only has `name`.

**JSON**
```json
{
    "firstname": "John",
    "lastname": "Doe",
    "age": 42
}
```
**Elm**
```elm

type alias Person =
    { name : String
    , age : Int
    }
    
person : Decoder Person
person =
    Field.require "firstname" Decode.string <| \firstname ->
    Field.require "lastname" Decode.string <| \lastname ->
    Field.require "age" Decode.int <| \age ->
    
    Decode.succeed
        { name = firstname ++ " " ++ lastname
        , age = age
        }
```

### Nested JSON objects

Using `requireAt` or `attemptAt` lets you reach down into nested objects. This is a
common use case when decoding graphQL responses.

**JSON**
```json
{
    "id": 321,
    "title": "About JSON decoders",
    "author": {
        "id": 123,
        "name": "John Doe",
    },
    "content": "..."
}
```
**Elm**
```elm

type alias BlogPost =
    { title : String
    , author : String
    , content : String
    }
    
blogpost : Decoder BlogPost
blogpost =
    Field.require "title" Decode.string <| \title ->
    Field.requireAt ["author", "name"] Decode.string <| \authorName ->
    Field.require "content" Decode.string <| \content ->
    
    Decode.succeed
        { title = title
        , author = authorName
        , content = content
        }
```

### Fail decoder if values are invalid

Here the decoder should fail if the person is younger than 18 yers old.

**JSON**
```json
{
    "name": "John Doe",
    "age": 42
}
```
**Elm**
```elm
type alias Person =
    { name : String
    , age : Int
    }
    
person : Decoder Person
person =
    Field.require "name" Decode.string <| \name ->
    Field.require "age" Decode.int <| \age ->

    if age < 18 then
        Decode.fail "You must be an adult"
    else
        Decode.succeed
            { name = name
            , age = age
            }
```

### Decode custom types

You can also use this package to build decoders for custom types.

**JSON**
```json
{
    "name": "John Doe",
    "id": 42
}
```
**Elm**
```elm
type User
    = Anonymous
    | Registered Int String

user : Decoder User
user =
    Field.attempt "id" Decode.int <| \maybeID ->
    Field.attempt "name" Decode.string <| \maybeName ->

    case (maybeID, maybeName) of
        (Just id, Just name) ->
            Registered id name
                |> Decode.succeed
        _ ->
            Decode.succeed Anonymous
```

## How does this work?

The following documentation assumes you are familiar with the following functions:

1. [Json.Decode.field](https://package.elm-lang.org/packages/elm/json/latest/Json-Decode#field)
2. [Json.Decode.map](https://package.elm-lang.org/packages/elm/json/latest/Json-Decode#map)
3. [Json.Decode.andThen](https://package.elm-lang.org/packages/elm/json/latest/Json-Decode#andThen)
4. Function application operator ([<|](https://package.elm-lang.org/packages/elm/core/latest/Basics#(<|)))

You can read more about those in [this guide](https://github.com/webbhuset/elm-json-decode/blob/master/TEACHING.md) by
Richard Feldman.

Consider this simple example:

```elm
import Json.Decode as Decode exposing (Decoder)

type alias User =
    { id : Int
    , name : String
    }


user : Decoder User
user =
    Decode.map2 User
        (Decode.field "id" Decode.int)
        (Decode.field "name" Decode.string)
```

Here, `map2` from [elm/json](https://package.elm-lang.org/packages/elm/json/latest/Json-Decode#map2) is used to decode a JSON object to a record.
The record constructor function is used (`User : Int -> String -> User`) to build the record.
This means that the order in which fields are written in the type declaration matters. For example, if you
change the order of fields `id` and `name` in yor record, you must also change the order of the two 
`(Decode.field ...)` rows to match the order of the record.

To use named bindings instead you can use `Json.Decode.andThen` write a decoder like this:

```elm
user : Decoder User
user =
    Decode.field "id" Decode.int
        |> Decode.andThen
            (\id ->
                Decode.field "name" Decode.string
                    |> Decode.andThen
                        (\name ->
                            Decode.succeed
                                { id = id
                                , name = name
                                }
                        )
            )
```
Now this looks ridiculous, but one thing is interesting: The record is
constructed using named variables (in the innermost function).

The fields are decoded one at the time with each decoded value being bound in turn to a
continuation function using `andThen`. The innermost function has access to
all the named argument variables from the outer scopes.

The above code can be improved by using the helper function `require`. Here is
the same decoder expressed in a cleaner way:

```elm
module Json.Decode.Field exposing (require)

require : String -> Decoder a -> (a -> Decoder b) -> Decoder b
require fieldName valueDecoder continuation =
    Decode.field fieldName valueDecoder
        |> Decode.andThen continuation

-- In User.elm
module User exposing (user)

import Json.Decode.Field as Field

user : Decoder User
user =
    Field.require "id" Decode.int
        (\id ->
            Field.require "name" Decode.string
                (\name ->
                    Decode.succeed
                        { id = id
                        , name = name
                        }
                )
        )
```
Nice: we got rid of some `andThen` noise.

Now let's format the code in a more readable way:

```elm
user : Decoder User
user =
    Field.require "id" Decode.int (\id ->
    Field.require "name" Decode.string (\name ->

    Decode.succeed
        { id = id
        , name = name
        }
    ))
```

We can also eliminate the parenthesis by using the backwards
[function application operator](https://package.elm-lang.org/packages/elm/core/latest/Basics#(<|)) (`<|`).

```elm
user : Decoder User
user =
    Field.require "id" Decode.int <| \id ->
    Field.require "name" Decode.string <| \name ->

    Decode.succeed
        { id = id
        , name = name
        }
```

This reads quite nicely. It's like two paragraphs.

* In the first paragraph we extract everything we need from the JSON object and
bind each value to a variable. Keeping the field decoder and the variable on the same row makes it
easy to read.
* In the second paragraph we build the actual Elm type using all the collected values.

It kind of maps to natural language:

> `require` a `Field` called `"id"` and `Decode` an `int`, bind the result to `id`\
> `require` a `Field` called `"name"` and `Decode` a `string`, bind the result to `name`
>
> The `Decode` will `succeed` with `{id = id, name = name}`


This way of formatting the code kind of resembles the `do` notation syntax found in Haskell or Pure Script.

```haskell
user : Decoder User
user = do
    id <- Field.require "id" Decode.int
    name <- Field.require "name" Decode.string

    return
        { id = id
        , name = name
        }
```

