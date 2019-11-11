/*
 * Copyright (c) 2019 Target Brands, Inc. All rights reserved.
 * Use of this source code is governed by the LICENSE file in this repository.
 */

/* Vela Typescript type definitions to encourage end-to-end type safety
 *
 * references:
 * - https://github.com/Punie/elm-typescript-starter/blob/master/src/elm/Main/index.d.ts
 * - https://github.com/dillonkearns/elm-typescript-interop
 */

export module Elm.Main {
  /**
   * Initializes the Elm app with the provided configuration
   *
   * @returns an instance of our bootstrapped Elm app
   */
  function init(config: Config): App;
}

/**
 * Minimal definition of an Elm App instance
 *
 */
export interface App {
  readonly ports: Ports;
}

/**
 * The Elm configuration object.
 *
 * @param node The node the Elm app should mount to; null makes Elm take over the whole app
 * @param flags The settings to bootstrap the Elm app with
 */
export type Config = {
  readonly node?: HTMLElement | null;
  readonly flags: Flags;
};

/**
 * Vela's custom flag configuration
 *
 */
export type Flags = {
  /** @property isDev a helper we might need to determine whether we are running in dev mode */
  readonly isDev: boolean;
  /** @property velaAPI the API of the server that the UI will interface with */
  readonly velaAPI: string;
  /** @property velaSourceBaseURL the base URL of the code management tool, ie. https://github.com */
  readonly velaSourceBaseURL: string;
  /** @property velaSourceClient the "Client ID" for the OAuth app set up in the source management tool */
  readonly velaSourceClient: string;
  /** @property velaSession used for passsing in an existing Vela session to Elm */
  readonly velaSession: Session | null;
};

/**
 * Defines the ports that are set up in Elm
 *
 */
export type Ports = {
  readonly storeSession: ToJS<Session>;
  readonly onSessionChange: ToElm<Session>;
};

/**
 * Allows for un/subscribing to messages sent from Elm to JS
 *
 */
export type ToJS<T> = {
  subscribe(callback: (value: T) => void): void;
  unsubscribe(callback: (value: T) => void): void;
};

/**
 * Allows for sending messages from JS to Elm
 *
 */
export type ToElm<T> = {
  send(value: T): void;
};

/**
 * The format of the session that we are working with in Vela
 *
 */
export type Session = {
  readonly username: string;
  readonly token: string;
};