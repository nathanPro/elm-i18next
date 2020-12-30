module I18Next exposing
    ( Translations, Delims(..), Replacements, CustomReplacements, initialTranslations
    , decoder
    , t, tr, tf, trf, customTr, customTrf
    , keys, hasKey
    , Tree, fromTree, string, object
    , encode, insert, toList
    )

{-| This library provides a solution to load and display translations in your
app. It allows you to load json translation files, display the text and
interpolate placeholders. There is also support for fallback languages if
needed.


## Types and Data

@docs Translations, Delims, Replacements, CustomReplacements, initialTranslations


## Decoding

Turn your JSON into translations.

@docs decoder


## Using Translations

Get translated values by key straight away, with replacements, fallback languages
or both.

@docs t, tr, tf, trf, customTr, customTrf


## Inspecting

You probably won't need these functions for regular applications if you just
want to translate some strings. But if you are looking to build a translations
editor you might want to query some information about the contents of the
translations.

@docs keys, hasKey


## Creating Translations Programmatically

Most of the time you'll load your translations as JSON from a server, but there
may be times, when you want to build translations in your code. The following
functions let you build a `Translations` value programmatically.

@docs Tree, fromTree, string, object

-}

import Dict exposing (Dict)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode


{-| A type representing a hierarchy of nested translations. You'll only ever
deal with this type directly, if you're using
[`string`](I18Next#string) and [`object`](I18Next#object).
-}
type Tree
    = Branch (Dict String Tree)
    | Leaf String


{-| A type that represents your loaded translations
-}
type Translations
    = Translations (Dict String String)


{-| A union type for representing delimiters for placeholders. Most commonly
those will be `{{...}}`, or `__...__`. You can also provide a set of
custom delimiters(start and end) to account for different types of placeholders.
-}
type Delims
    = Curly
    | Underscore
    | Custom ( String, String )


{-| An alias for replacements for use with placeholders. Each tuple should
contain the name of the placeholder as the first value and the value for
the placeholder as the second entry. See [`tr`](I18Next#tr) and
[`trf`](I18Next#trf) for usage examples.
-}
type alias Replacements =
    List ( String, String )


{-| Use this to initialize Translations in your model. This may be needed
when loading translations but you need to initialize your model before
your translations are fetched.
-}
initialTranslations : Translations
initialTranslations =
    Translations Dict.empty


{-| Use this to obtain a list of keys that are contained in the translations.
From this it is simple to, for example, compare two translations for keys defined in one
but not the other. The order of the keys is arbitrary and should not be relied
on.
-}
keys : Translations -> List String
keys (Translations dict) =
    Dict.keys dict


{-| This function lets you check whether a certain key is exists in your
translations.
-}
hasKey : Translations -> String -> Bool
hasKey (Translations dict) key =
    Dict.member key dict


{-| Converts a Translations into a list of keys and their respective
translations |
-}
toList : Translations -> List ( String, String )
toList (Translations d) =
    Dict.toList d


{-| |
-}
insert : String -> String -> Translations -> Translations
insert k v (Translations d) =
    Translations (Dict.insert k v d)


{-| Decode a JSON translations file. The JSON can be arbitrarly nested, but the
leaf values can only be strings. Use this decoder directly, if you are passing
the translations JSON into your elm app via flags or ports.
After decoding nested values will be available with any of the translate
functions separated with dots.

    {- The JSON could look like this:
    {
      "buttons": {
        "save": "Save",
        "cancel": "Cancel"
      },
      "greetings": {
        "hello": "Hello",
        "goodDay": "Good Day {{firstName}} {{lastName}}"
      }
    }
    -}

    --Use the decoder like this on a string
    import I18Next
    Json.Decode.decodeString I18Next.decoder "{ \"greet\": \"Hello\" }"

    -- or on a Json.Encode.Value
    Json.Decode.decodeValue I18Next.decoder encodedJson

-}
encode : Translations -> Json.Encode.Value
encode (Translations d) =
    Json.Encode.dict (\s -> s) Json.Encode.string d


decoder : Decoder Translations
decoder =
    Decode.dict treeDecoder
        |> Decode.map (flattenTranslations >> Translations)


treeDecoder : Decoder Tree
treeDecoder =
    Decode.oneOf
        [ Decode.string |> Decode.map Leaf
        , Decode.lazy
            (\_ -> Decode.dict treeDecoder |> Decode.map Branch)
        ]


flattenTranslations : Dict String Tree -> Dict String String
flattenTranslations =
    flattenTranslationsHelp Dict.empty ""


flattenTranslationsHelp : Dict String String -> String -> Dict String Tree -> Dict String String
flattenTranslationsHelp initialValue namespace dict =
    Dict.foldl
        (\key val acc ->
            let
                newNamespace currentKey =
                    if String.isEmpty namespace then
                        currentKey

                    else
                        namespace ++ "." ++ currentKey
            in
            case val of
                Leaf str ->
                    Dict.insert (newNamespace key) str acc

                Branch children ->
                    flattenTranslationsHelp acc (newNamespace key) children
        )
        initialValue
        dict


{-| Translate a value at a given string.

    {- If your translations are { "greet": { "hello": "Hello" } }
    use dots to access nested keys.
    -}
    import I18Next exposing (t)
    t translations "greet.hello" -- "Hello"

-}
t : Translations -> String -> String
t (Translations translations) key =
    Dict.get key translations |> Maybe.withDefault key


delimsToTuple : Delims -> ( String, String )
delimsToTuple delims =
    case delims of
        Curly ->
            ( "{{", "}}" )

        Underscore ->
            ( "__", "__" )

        Custom tuple ->
            tuple


{-| CustomReplacements if you want to replace placeholders with other things
than strings. The tuples should
contain the name of the placeholder as the first value and the value for
the placeholder as the second entry. It can be anything, for example `Html`. See [`customTf`](I18Next#customTr) and
[`customTrf`](I18Next#customTrf) for usage examples.
-}
type alias CustomReplacements a =
    List ( String, a )


type Partial a
    = Text String
    | Value a


{-| Sometimes it can be useful to replace placeholders with other things than just `String`s.
Imagine you have translations containing a sentence with a link and you want to
provide the proper markup.
_Hint:_ The third argument is a function which will be called for any string pieces that
AREN'T placeholders, so that the types of replacements and the other other string parts match.
In most cases you'll just pass `Html.text` here.

    {- If your translations are { "call-to-action": "Go to {{elm-website}} for more information." }
    ...
    -}
    import Html exposing (text, a)

    customTr translationsEn Curly text "call-to-action" [ ( "elm-website", a [href "https://elm-lang.org"] [text "https://elm-lang.org"] ) ]
    -- Go to <a href="https://elm-lang.org">https://elm-lang.org</a> for more information.

If you only want `String`s though, use [`tr`](I18Next#tr) instead.

-}
customTr : Translations -> Delims -> (String -> a) -> String -> CustomReplacements a -> List a
customTr (Translations d) delims lift key reps =
    let
        ( start, end ) =
            delimsToTuple delims

        pattern : String -> String
        pattern k =
            start ++ k ++ end

        collapse : Partial a -> a
        collapse p =
            case p of
                Text s ->
                    lift s

                Value v ->
                    v

        replace : ( String, a ) -> String -> List (Partial a)
        replace ( k, v ) =
            String.split (pattern k)
                >> List.map Text
                >> List.intersperse (Value v)

        replaceTexts : ( String, a ) -> List (Partial a) -> List (Partial a)
        replaceTexts subs =
            List.foldl
                (\partial ->
                    \acc ->
                        case partial of
                            Text s ->
                                List.append acc (replace subs s)

                            _ ->
                                List.append acc [ partial ]
                )
                []
    in
    Maybe.map (\s -> List.foldl replaceTexts [ Text s ] reps |> List.map collapse)
        (Dict.get key d)
        |> Maybe.withDefault [ lift key ]


{-| Like [`customTr`](I18Next#customTr) but with support for fallback languages.
-}
customTrf : List Translations -> Delims -> (String -> a) -> String -> CustomReplacements a -> List a
customTrf =
    resolveFallbacks >> customTr


{-| Translate a value at a key, while replacing placeholders.
Check the [`Delims`](I18Next#Delims) type for
reference how to specify placeholder delimiters.
Use this when you need to replace placeholders.

    -- If your translations are { "greet": "Hello {{name}}" }
    import I18Next exposing (tr, Delims(..))
    tr translations Curly "greet" [("name", "Peter")]

-}
tr : Translations -> Delims -> String -> Replacements -> String
tr translations delims key replacements =
    customTr translations delims (\s -> s) key replacements |> String.concat


{-| Translate a value and try different fallback languages by providing a list
of Translations. If the key you provide does not exist in the first of the list
of languages, the function will try each language in the list.

    {- Will use german if the key exists there, or fall back to english
    if not. If the key is not in any of the provided languages the function
    will return the key. -}
    import I18Next exposing (tf)
    tf [germanTranslations, englishTranslations] "labels.greetings.hello"

-}
tf : List Translations -> String -> String
tf =
    resolveFallbacks >> t


fallback : Translations -> Translations -> Translations
fallback (Translations d) (Translations f) =
    Translations (Dict.union d f)


resolveFallbacks : List Translations -> Translations
resolveFallbacks =
    List.foldr fallback initialTranslations


{-| Combines the [`tr`](I18Next#tr) and the [`tf`](I18Next#tf) function.
Only use this if you want to replace placeholders and apply fallback languages
at the same time.

    -- If your translations are { "greet": "Hello {{name}}" }
    import I18Next exposing (trf, Delims(..))
    let
      langList = [germanTranslations, englishTranslations]
    in
      trf langList Curly "greet" [("name", "Peter")] -- "Hello Peter"

-}
trf : List Translations -> Delims -> String -> Replacements -> String
trf =
    resolveFallbacks >> tr


{-| Represents the leaf of a translations tree. It holds the actual translation
string.
-}
string : String -> Tree
string =
    Leaf


{-| Let's you arange your translations in a hierarchy of objects.
-}
object : List ( String, Tree ) -> Tree
object =
    Dict.fromList >> Branch


{-| Create a [`Translations`](I18Next#Translations) value from a list of pairs.

    import I18Next exposing (string, object, fromTree, t)

    translations =
        fromTree
          [ ("custom"
            , object
                [ ( "morning", string "Morning" )
                , ( "evening", string "Evening" )
                , ( "afternoon", string "Afternoon" )
                ]
            )
          , ("hello", string "hello")
          ]

    -- use it like this
    t translations "custom.morning" -- "Morning"

-}
fromTree : List ( String, Tree ) -> Translations
fromTree =
    Dict.fromList >> flattenTranslations >> Translations
