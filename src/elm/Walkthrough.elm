{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Walkthrough exposing (Model, Step(..), defaultConfig, viewToggle)

import Html exposing (Html, a, button, details, div, li, summary, text, ul)
import Html.Attributes exposing (attribute, class, href, id)
import Html.Events exposing (onClick)
import Util


type alias Model =
    { step : Step
    , toggle : Bool
    }


type Step
    = Null
    | Step1
    | Step2
    | Finish


defaultConfig : Model
defaultConfig =
    Model Null False


viewToggle : { step : Step, toggle : Bool } -> msg -> (Step -> msg) -> Html msg
viewToggle { step, toggle } noOp setStep =
    li
        [ id "walkthrough-toggle"
        ]
        [ details
            [ class "details"
            , class "walkthrough-toggle"
            , class "-no-pad"
            , attribute "role" "button"
            , Util.open toggle
            , Util.onClickPreventDefault noOp
            ]
            [ summary
                [ class "summary"
                , class "-no-pad"
                , id "walkthrough-toggle-trigger"
                ]
                [ Html.span [ id "walkthrough-toggle-trigger", class "button", class "-link" ] [ text "help" ] ]

            -- [ text "help" ]
            , div [ class "walkthrough-toggle-tooltip" ] <| viewEnableWalkthrough setStep
            ]
        ]


viewEnableWalkthrough : (Step -> msg) -> List (Html msg)
viewEnableWalkthrough setStep =
    [ div [ class "-arrow" ] []
    , div [] [ text "Need help getting started?" ]
    , div []
        [ text "Visit our "
        , a [ class "link", href docsLink ] [ text "docs" ]
        , text ", or try out the guided tour!"
        , button [ class "button", class "-outline", onClick (setStep Step1) ] [ text "start tour" ]
        ]
    ]


docsLink : String
docsLink =
    "https://go-vela.github.io/docs/usage/"
