# Continuation-passing style Json decoder in Elm

This packages helps you writing JSON decoders in a [Continuation-passing](https://en.wikipedia.org/wiki/Continuation-passing_style) style.
This enables you use named bindings for field names which is very useful when
decoding JSON objects to Elm records or custom types.

## Example

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
The approach [suggested by the core JSON library](https://package.elm-lang.org/packages/elm/json/latest/Json-Decode#map3) is to use the `Json.Decode.mapX` family of decoders to build
a record.

```elm
import Json.Decode as Json exposing (Decoder)

person : Decoder Person
person =
    Json.map5 Person
        (Json.field "id" Json.int)
        (Json.field "name" Json.string)
        (Json.maybe <| Json.field "weight" Json.int)
        (Json.field "likes" Json.int
            |> Json.maybe
            |> Json.map (Maybe.withDefault 0)
        )
        (Json.succeed "Hardcoded Value")
```

Using this package you can write the same decoder like this:
```elm
import Json.Decode as Json exposing (Decoder)
import Json.Decode.Field as Field

person : Decoder Person
person =
    Field.required "name" Json.string (\name ->
    Field.required "id" Json.int (\id ->
    Field.optional "weight" Json.int (\maybeWeight ->
    Field.optional "likes" Json.int (\maybeLikes ->
        Json.succeed
            { name = name
            , id = id
            , maybeWeight = maybeWeight
            , likes = Maybe.withDefault 0 maybeLikes
            , hardcoded = "Hardcoded Value"
            }
    ))))
```

The main advantages over using `mapX` are:

* Record field order does not matter. Named bindings are used instead of order. You can change the order of the fields in the type declaration (`type alias Person ...`) without breaking the decoder.
* Easier to see how the record is connected to the JSON object. Especially when there are many fields. Sometimes the JSON fields have different names than your Elm record.
* Easier to add fields down the line.
* If all fields of the record are of the same type you won't get any compiler error with the `mapX` approach if you mess up the order. Since named binding is used here it makes it much easier to get things right.
* Sometimes fields needs futher validation / processing. See below examples.
* If you have more than 8 fields in your object you can't use the `Json.Decode.mapX` approach since [map8](https://package.elm-lang.org/packages/elm/json/latest/Json-Decode#map8) is the largest map function.

## More Examples

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
    Field.required "firstname" Json.string (\firstname ->
    Field.required "lastname" Json.string (\lastname ->
    Field.required "age" Json.int (\age ->
        Json.succeed
            { name = firstname ++ " " ++ lastname
            , age = age
            }
    )))
```

### Nested JSON objects

Using `requiredAt` or `optionalAt` you can reach down into nested objects. This is a
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
    Field.required "title" Json.string (\title ->
    Field.requiredAt ["author", "name"] Json.string (\authorName ->
    Field.required "content" Json.string (\content ->
        Json.succeed
            { title = title
            , author = authorName
            , content = content
            }
    )))
```

### Fail decoder if values are invalid

Here, the decoder should fail if the person is below 18.

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
    Field.required "name" Json.string (\name ->
    Field.required "age" Json.int (\age ->
        if age < 18 then
            Json.fail "You must be an adult"
        else
            Json.succeed
                { name = name
                , age = age
                }
    ))
```

### Custom types

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
    Field.optional "id" Json.int (\maybeID ->
    Field.optional "name" Json.string (\maybeName ->
        case (maybeID, maybeName) of
            (Just id, Just name) ->
                Registered id name
                    |> Json.succeed
            _ ->
                Json.succeed Anonymous
    ))
```

## How does this work?

Consider this simple example:

```elm
import Json.Decode as Json exposing (Decoder)

type alias User =
    { id : Int
    , name : String
    }


user : Decoder User
user =
    Json.map2 User
        (Json.field "id" Json.int)
        (Json.field "name" Json.string)
```

Here, `map2` from [elm/json](https://package.elm-lang.org/packages/elm/json/latest/Json-Decode#map2) is used to decode a JSON object to a record.
The record constructor function is used (`User : Int -> String -> User`) to build the record.
This means that the order fields are written in the type declaration matters. If you
change the order of fields `id` and `name` in yor record, you have to change the order of the two 
`(Json.field ...)` rows to match the order of the record.

To use named bindings instead you can use `Json.Decode.andThen` write a decoder like this:

```elm
user : Decoder User
user =
    Json.field "id" Json.int
        |> Json.andThen
            (\id ->
                Json.field "name" Json.string
                    |> Json.andThen
                        (\name ->
                            Json.succeed
                                { id = id
                                , name = name
                                }
                        )
            )
```
Now this looks ridicolus, but one thing is interesting: The record is
constructed using named variables (in the innermost function).

The fields are decoded one at the time and then the decoded value is bound to a
contiunation function using `andThen`. The innermost function will have access to
all the named argument variables from the outer scopes.

The above code can be improved by using the helper function `required`. This is
the same decoder expressed in a cleaner way:

```elm
module Json.Decode.Field exposing (required)

required : String -> Decoder a -> (a -> Decoder b) -> Decoder b
required fieldName valueDecoder continuation =
    Json.field fieldName valueDecoder
        |> Json.andThen continuation

-- In User.elm
module User exposing (user)

import Json.Decode.Field as Field

user : Decoder User
user =
    Field.required "id" Json.int
        (\id ->
            Field.required "name" Json.string
                (\name ->
                    Json.succeed
                        { id = id
                        , name = name
                        }
                )
        )
```
Now we got rid of some `andThen` noise.

Finally, if you format the code like this it gets even more clear
what is going on:

```elm
user : Decoder User
user =
    Field.required "id" Json.int (\id ->
    Field.required "name" Json.string (\name ->
        Json.succeed
            { id = id
            , name = name
            }
    ))
```
This reads quite nice.

* First you extract everything you need from the JSON object and
bind each field to a variable. Keeping the field decoder and the variable on the same row makes it
easy to read.
* Then you build the record using all collected values.

