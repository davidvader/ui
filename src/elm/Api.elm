{--
Copyright (c) 2019 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Api exposing
    ( Request(..)
    , addRepository
    , deleteRepo
    , getAllBuilds
    , getAllRepositories
    , getBuild
    , getBuilds
    , getRepositories
    , getSourceRepositories
    , getStep
    , getStepLogs
    , getSteps
    , getUser
    , restartBuild
    , try
    , tryAll
    )

import Api.Endpoint as Endpoint exposing (Endpoint(..))
import Api.Pagination as Pagination
import Http
import Http.Detailed
import Json.Decode exposing (Decoder)
import RemoteData exposing (RemoteData(..), WebData)
import Task exposing (Task)
import Vela
    exposing
        ( AuthParams
        , Build
        , BuildNumber
        , Builds
        , Log
        , Org
        , Repo
        , Repositories
        , Repository
        , SourceRepositories
        , Step
        , StepNumber
        , Steps
        , User
        , decodeBuild
        , decodeBuilds
        , decodeLog
        , decodeRepositories
        , decodeRepository
        , decodeSourceRepositories
        , decodeStep
        , decodeSteps
        , decodeUser
        , defaultUser
        )



-- TYPES


{-| RequestConfig : a basic configuration record for an API request
-}
type alias RequestConfig a =
    { method : String
    , headers : List Http.Header
    , url : String
    , body : Http.Body
    , decoder : Decoder a
    }


{-| Request : wraps a configuration for an API request
-}
type Request a
    = Request (RequestConfig a)


{-| ListResponse : a custom response type to be used in conjunction
with API pagination response headers to discern between
a response that has more pages to fetch vs a response that has
no further pages.
-}
type ListResponse a
    = Partial (Request a) (List a)
    | Done (List a)


{-| PartialModel : an abbreviated version of the main model
-}
type alias PartialModel a =
    { a
        | velaAPI : String
        , user : WebData User
    }



-- HELPERS


{-| remoteDataToUser : simple helper to turn a RemoteData User into a User
-}
remoteDataToUser : WebData User -> User
remoteDataToUser maybeUser =
    Maybe.withDefault defaultUser <| RemoteData.toMaybe maybeUser


{-| request : turn a request configuration into a request
-}
request : RequestConfig a -> Request a
request =
    Request


{-| toTask : turn a request config into an HTTP task
-}
toTask : Request a -> Task (Http.Detailed.Error String) ( Http.Metadata, a )
toTask (Request config) =
    Http.task
        { body = config.body
        , headers = config.headers
        , method = config.method
        , resolver = Http.stringResolver <| Http.Detailed.responseToJson config.decoder
        , timeout = Nothing
        , url = config.url
        }


{-| toAllTask : like _toTask_ but attaches a custom resolver to use in conjunction with _tryAll_
-}
toAllTask : Request a -> Task (Http.Detailed.Error String) ( Http.Metadata, ListResponse a )
toAllTask (Request config) =
    Http.task
        { body = config.body
        , headers = config.headers
        , method = config.method
        , resolver = Http.stringResolver (listResponseResolver config)
        , timeout = Nothing
        , url = config.url
        }


{-| listResponseToList : small helper that forwards the inital HTTP task to the recurse function
-}
listResponseToList : Task (Http.Detailed.Error String) ( Http.Metadata, ListResponse a ) -> Task (Http.Detailed.Error String) ( Http.Metadata, List a )
listResponseToList task =
    task |> recurse


{-| listResponseResolver : turns a response from an HTTP request into a 'ListResponse' response
-}
listResponseResolver : RequestConfig a -> Http.Response String -> Result (Http.Detailed.Error String) ( Http.Metadata, ListResponse a )
listResponseResolver config response =
    case response of
        Http.GoodStatus_ m _ ->
            let
                items : Result (Http.Detailed.Error String) ( Http.Metadata, List a )
                items =
                    Http.Detailed.responseToJson (Json.Decode.list config.decoder) response

                next : Maybe String
                next =
                    Pagination.get m.headers
                        |> Pagination.maybeNextLink
            in
            case next of
                Nothing ->
                    Result.map (\( _, res ) -> ( m, Done res )) items

                Just url ->
                    Result.map (\( _, res ) -> ( m, Partial (request { config | url = url }) res )) items

        Http.BadUrl_ b ->
            Err (Http.Detailed.BadUrl b)

        Http.Timeout_ ->
            Err Http.Detailed.Timeout

        Http.NetworkError_ ->
            Err Http.Detailed.NetworkError

        Http.BadStatus_ m b ->
            Err (Http.Detailed.BadStatus m b)


{-| recurse : keeps firing off HTTP tasks if the response is of type Partial

    Thanks to "https://github.com/correl/elm-paginated" for the inspiration

-}
recurse : Task (Http.Detailed.Error String) ( Http.Metadata, ListResponse a ) -> Task (Http.Detailed.Error String) ( Http.Metadata, List a )
recurse originalRequest =
    originalRequest
        |> Task.andThen
            (\( meta, response ) ->
                case response of
                    Partial request_ _ ->
                        toAllTask request_
                            |> Task.map (update ( meta, response ))
                            |> recurse

                    Done data ->
                        Task.succeed ( meta, data )
            )


{-| update: aggregates the results from two responses as needed
-}
update : ( Http.Metadata, ListResponse a ) -> ( Http.Metadata, ListResponse a ) -> ( Http.Metadata, ListResponse a )
update old new =
    case ( old, new ) of
        ( ( _, Done _ ), _ ) ->
            old

        ( ( _, Partial _ oldItems ), ( meta, Done newItems ) ) ->
            ( meta, Done (oldItems ++ newItems) )

        ( ( _, Partial _ oldItems ), ( meta, Partial request_ newItems ) ) ->
            ( meta, Partial request_ (oldItems ++ newItems) )


{-| withAuth : returns an auth header with given Bearer token
-}
withAuth : WebData User -> Request a -> Request a
withAuth user (Request config) =
    let
        user_ =
            remoteDataToUser user
    in
    request { config | headers = Http.header "authorization" ("Bearer " ++ user_.token) :: config.headers }



-- METHODS


{-| get : creates a GET request configuration
-}
get : String -> Endpoint -> Decoder b -> Request b
get api endpoint decoder =
    request
        { method = "GET"
        , headers = []
        , url = Endpoint.toUrl api endpoint
        , body = Http.emptyBody
        , decoder = decoder
        }


{-| post : creates a POST request configuration
-}
post : String -> Endpoint -> Http.Body -> Decoder b -> Request b
post api endpoint body decoder =
    request
        { method = "POST"
        , headers = []
        , url = Endpoint.toUrl api endpoint
        , body = body
        , decoder = decoder
        }


{-| put : creates a PUT request configuration
-}
put : String -> Endpoint -> Http.Body -> Decoder b -> Request b
put api endpoint body decoder =
    request
        { method = "PUT"
        , headers = []
        , url = Endpoint.toUrl api endpoint
        , body = body
        , decoder = decoder
        }


{-| delete : creates a DELETE request configuration
-}
delete : String -> Endpoint -> Request String
delete api endpoint =
    request
        { method = "DELETE"
        , headers = []
        , url = Endpoint.toUrl api endpoint
        , body = Http.emptyBody
        , decoder = Json.Decode.string
        }



-- ENTRYPOINT


{-| try : default way to request information from and endpoint

    example usage:
        Api.try UserResponse <| Api.getUser model authParams

-}
try : (Result (Http.Detailed.Error String) ( Http.Metadata, a ) -> msg) -> Request a -> Cmd msg
try msg request_ =
    toTask request_
        |> Task.attempt msg


{-| tryAll : will attempt to get all results for the endpoint based on pagination

    example usage:
        Api.tryAll RepositoriesResponse <| Api.getAllRepositories model

-}
tryAll : (Result (Http.Detailed.Error String) ( Http.Metadata, List a ) -> msg) -> Request a -> Cmd msg
tryAll msg request_ =
    toAllTask request_
        |> listResponseToList
        |> Task.attempt msg



-- OPERATIONS


{-| getUser : fetches a user and token from the authentication endpoint
-}
getUser : PartialModel a -> AuthParams -> Request User
getUser model { code, state } =
    get model.velaAPI (Endpoint.Authenticate { code = code, state = state }) decodeUser


{-| getRepositories : fetches added repositories by user token
-}
getRepositories : PartialModel a -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Request Repositories
getRepositories model maybePage maybePerPage =
    get model.velaAPI (Endpoint.Repositories maybePage maybePerPage) decodeRepositories
        |> withAuth model.user


{-| getAllRepositories : used in conjuction with 'tryAll', it retrieves all pages of the resource

    Note: the singular version of the type/decoder is needed in this case as it turns it into a list

-}
getAllRepositories : PartialModel a -> Request Repository
getAllRepositories model =
    -- we using the max perPage setting of 100 to reduce the number of calls
    get model.velaAPI (Endpoint.Repositories (Just 1) (Just 100)) decodeRepository
        |> withAuth model.user


{-| getSourceRepositories : fetches source repositories by username for creating them via api
-}
getSourceRepositories : PartialModel a -> Request SourceRepositories
getSourceRepositories model =
    get model.velaAPI Endpoint.UserSourceRepositories decodeSourceRepositories
        |> withAuth model.user


{-| deleteRepo : removes an added repository
-}
deleteRepo : PartialModel a -> Repository -> Request String
deleteRepo model repository =
    delete model.velaAPI (Endpoint.Repository repository.org repository.name)
        |> withAuth model.user


{-| addRepository : adds a repository
-}
addRepository : PartialModel a -> Http.Body -> Request Repository
addRepository model body =
    post model.velaAPI (Endpoint.Repositories Nothing Nothing) body decodeRepository
        |> withAuth model.user


{-| restartBuild : restarts a build
-}
restartBuild : PartialModel a -> Org -> Repo -> BuildNumber -> Request Build
restartBuild model org repository buildNumber =
    post model.velaAPI (Endpoint.Build org repository buildNumber) Http.emptyBody decodeBuild
        |> withAuth model.user


{-| getBuilds : fetches vela builds by repository
-}
getBuilds : PartialModel a -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Org -> Repo -> Request Builds
getBuilds model maybePage maybePerPage org repository =
    get model.velaAPI (Endpoint.Builds maybePage maybePerPage org repository) decodeBuilds
        |> withAuth model.user


{-| getAllBuilds : used in conjuction with 'tryAll', it retrieves all pages of the resource

    Note: the singular version of the type/decoder is needed in this case as it turns it into a list

-}
getAllBuilds : PartialModel a -> Org -> Repo -> Request Build
getAllBuilds model org repository =
    -- we using the max perPage setting of 100 to reduce the number of calls
    get model.velaAPI (Endpoint.Builds (Just 1) (Just 100) org repository) decodeBuild
        |> withAuth model.user


{-| getBuild : fetches vela build by repository and build number
-}
getBuild : PartialModel a -> Org -> Repo -> BuildNumber -> Request Build
getBuild model org repository buildNumber =
    get model.velaAPI (Endpoint.Build org repository buildNumber) decodeBuild
        |> withAuth model.user


{-| getSteps : fetches vela build steps by repository and build number
-}
getSteps : PartialModel a -> Maybe Pagination.Page -> Maybe Pagination.PerPage -> Org -> Repo -> BuildNumber -> Request Steps
getSteps model maybePage maybePerPage org repository buildNumber =
    get model.velaAPI (Endpoint.Steps maybePage maybePerPage org repository buildNumber) decodeSteps
        |> withAuth model.user


{-| getStep : fetches vela build steps by repository, build number and step number
-}
getStep : PartialModel a -> Org -> Repo -> BuildNumber -> StepNumber -> Request Step
getStep model org repository buildNumber stepNumber =
    get model.velaAPI (Endpoint.Step org repository buildNumber stepNumber) decodeStep
        |> withAuth model.user


{-| getStepLogs : fetches vela build step log by repository, build number and step number
-}
getStepLogs : PartialModel a -> Org -> Repo -> BuildNumber -> StepNumber -> Request Log
getStepLogs model org repository buildNumber stepNumber =
    get model.velaAPI (Endpoint.StepLogs org repository buildNumber stepNumber) decodeLog
        |> withAuth model.user