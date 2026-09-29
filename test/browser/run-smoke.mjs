import { join } from "node:path";
import { bundle, checks, launch, page, rootDir, serve, watchProblems } from "../support.mjs";

const { expect, report } = checks("browser-smoke");

const withApp = async (browser, module, run) => {
  const outfile = join(rootDir, "dist", "browser-smoke", `${module}.js`);
  bundle(module, outfile);
  const { server, origin } = await serve({ "/": page("/app.js"), "/app.js": outfile });
  const tab = await browser.newPage();
  const problems = watchProblems(tab);
  try {
    await tab.goto(origin);
    await run(tab);
    expect(`${module}: no page errors or warnings`, problems, []);
  } finally {
    await tab.close();
    server.close();
  }
};

const counter = async (tab) => {
  const value = () => tab.textContent(".counter-value");
  await tab.waitForSelector(".counter-value");
  expect("counter starts at 0", await value(), "0");
  await tab.click("text=+ step");
  await tab.click("text=+ step");
  expect("+ step twice", await value(), "2");
  await tab.click(".counter-presets >> text=5");
  await tab.click("text=+ step");
  expect("step preset 5", await value(), "7");
  expect("doubled follows", await tab.textContent(".counter-meta span"), "14");
  expect("trend class is reactive", await tab.getAttribute(".counter-meta span:nth-of-type(2)", "class"), "positive");
  await tab.click("text=Reset");
  expect("reset", await value(), "0");
  expect("event log entries", await tab.locator(".counter-log li").count(), 6);
  await tab.click(".counter-log-head >> text=Clear");
  expect("log cleared", await tab.textContent(".counter-empty"), "No events yet.");
};

const todomvc = async (tab) => {
  const add = async (title) => {
    await tab.fill(".new-todo", title);
    await tab.press(".new-todo", "Enter");
  };
  const titles = () => tab.$$eval(".todo-list .todo .todo-title", (nodes) => nodes.map((n) => n.textContent));
  await tab.waitForSelector(".new-todo");
  await add("write bindings");
  await add("ship solid 2");
  expect("todos added", await titles(), ["write bindings", "ship solid 2"]);
  expect("draft cleared", await tab.inputValue(".new-todo"), "");
  expect("count", await tab.textContent(".todo-count"), "2 items left");

  const firstRow = tab.locator(".todo").first();
  const firstRowHandle = await firstRow.elementHandle();
  await firstRow.locator(".todo-toggle").check();
  expect("toggle marks completed", await firstRow.getAttribute("class"), "todo completed");
  expect("count after toggle", await tab.textContent(".todo-count"), "1 item left");
  expect("row DOM reused after update", await tab.evaluate((el) => el.isConnected, firstRowHandle), true);

  await tab.click("text=Active");
  expect("active filter", await titles(), ["ship solid 2"]);
  expect("selected filter class", await tab.getAttribute(".filters button:nth-child(2)", "class"), "filter-btn selected");
  await tab.click("text=Completed");
  expect("completed filter", await titles(), ["write bindings"]);
  await tab.click(".filters >> text=All");
  await tab.click("text=Clear completed");
  expect("clear completed", await titles(), ["ship solid 2"]);
  await tab.check(".toggle-all");
  expect("toggle all", await tab.textContent(".todo-count"), "0 items left");
  await tab.click(".destroy");
  expect("delete last todo shows empty state", await tab.textContent(".empty-state"), "Add your first task to get started.");
};

const browser = await launch();
try {
  await withApp(browser, "Examples.Counter", counter);
  await withApp(browser, "Examples.TodoMVC", todomvc);
} finally {
  await browser.close();
}
report();
