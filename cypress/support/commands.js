// ***********************************************
// This example commands.js shows you how to
// create various custom commands and overwrite
// existing commands.
//
// For more comprehensive examples of custom
// commands please read more here:
// https://on.cypress.io/custom-commands
// ***********************************************

// Login helper
Cypress.Commands.add("login", (path = "/") => {
  cy.fixture("sessionstorage").then(sessionstorageSample => {
    cy.visit(path, {
      onBeforeLoad: win => {
        const serialized = JSON.stringify(sessionstorageSample);
        win.sessionStorage.setItem("vela", serialized);
      }
    });
  });
});

// Route stubbing helpers
Cypress.Commands.add("stubBuild", () => {
  cy.server();
  cy.fixture("build_running.json").as("runningBuild");
  cy.fixture("build_pending.json").as("pendingBuild");
  cy.fixture("build_success.json").as("successBuild");
  cy.fixture("build_failure.json").as("failureBuild");
  cy.route({
      method: "GET",
      url: "api/v1/repos/*/*/builds/1",
      status: 200,
      response: "@runningBuild"
  });
  cy.route({
      method: "GET",
      url: "api/v1/repos/*/*/builds/2",
      status: 200,
      response: "@pendingBuild"
  });
  cy.route({
      method: "GET",
      url: "api/v1/repos/*/*/builds/3",
      status: 200,
      response: "@successBuild"
  });
  cy.route({
      method: "GET",
      url: "api/v1/repos/*/*/builds/4",
      status: 200,
      response: "@failureBuild"
  });
});

Cypress.Commands.add("stubBuilds", () => {
  cy.server();
  cy.fixture("builds_50.json").as("buildsPage1");
  cy.fixture("builds_5.json").as("buildsPage2");
  cy.route({
    method: "GET",
    url: "*api/v1/repos/*/*/builds?page=1&per_page=100",
    headers: {
      link: `<http://localhost:8888/api/v1/repos/someorg/somerepo/builds?page=2&per_page=100>; rel="next", <http://localhost:8888/api/v1/repos/someorg/somerepo/builds?page=2&per_page=100>; rel="last",`
    },
    response: "@buildsPage1"
  });
  cy.route({
    method: "GET",
    url: "*api/v1/repos/*/*/builds?page=2&per_page=100*",
    headers: {
      link: `<http://localhost:8888/api/v1/repos/someorg/somerepo/builds?page=1&per_page=100>; rel="first", <http://localhost:8888/api/v1/repos/someorg/somerepo/builds?page=1&per_page=100>; rel="prev",`
    },
    response: "@buildsPage2"
  });
});


Cypress.Commands.add("stubStepsWithLogs", () => {
  cy.server();
  cy.fixture("steps_5.json").as("steps");
  cy.route({
      method: "GET",
      url: "api/v1/repos/*/*/builds/*/steps",
      status: 200,
      response: "@steps"
  });
  cy.fixture("logs").then(logs => {
    for (let i = 0; i < logs.length; i++) {
      cy.route({
        method: "GET",
        url: "api/v1/repos/*/*/builds/*/steps/"+logs[i]['step_id']+"/logs",
        status: 200,
        response: logs[i]
      });
    }
  });
});