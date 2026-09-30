import { createProjection, createSignal, For } from "solid-js";
import { render } from "@solidjs/web";

const adjectives = ["pretty", "large", "big", "small", "tall", "short", "long", "handsome", "plain", "quaint", "clean", "elegant", "easy", "angry", "crazy", "helpful", "mushy", "odd", "unsightly", "adorable", "important", "inexpensive", "cheap", "expensive", "fancy"];
const colours = ["red", "yellow", "blue", "green", "pink", "brown", "purple", "brown", "white", "black", "orange"];
const nouns = ["table", "chair", "house", "bbq", "desk", "car", "pony", "cookie", "sandwich", "burger", "pizza", "mouse", "keyboard"];

let seed = 42;
let nextId = 0;

const pick = (words) => {
  seed = (seed * 75 + 74) % 65537;
  return words[seed % words.length];
};

const buildRows = (count) => {
  const rows = new Array(count);
  for (let i = 0; i < count; i += 1) {
    const id = (nextId += 1);
    const text = `${pick(adjectives)} ${pick(colours)} ${pick(nouns)}`;
    const [label, setLabel] = createSignal(text);
    rows[i] = { id, label, setLabel };
  }
  return rows;
};

const Button = (props) => (
  <button id={props.id} type="button" onClick={props.onClick}>
    {props.text}
  </button>
);

const App = () => {
  const [rows, setRows] = createSignal([]);
  const [selected, setSelected] = createSignal(0);
  let previous;
  const isSelected = createProjection((draft) => {
    const next = selected();
    if (previous !== undefined && previous !== next) delete draft[previous];
    draft[next] = true;
    previous = next;
  }, {});

  const swapRows = () =>
    setRows((current) => {
      if (current.length <= 998) return current;
      const next = current.slice();
      const a = next[1];
      next[1] = next[998];
      next[998] = a;
      return next;
    });

  const updateEveryTenth = () => {
    const current = rows();
    for (let i = 0; i < current.length; i += 10) current[i].setLabel((label) => label + " !!!");
  };

  return (
    <div class="container">
      <div class="jumbotron">
        <Button id="run" text="Create 1,000 rows" onClick={() => setRows(buildRows(1000))} />
        <Button id="runlots" text="Create 10,000 rows" onClick={() => setRows(buildRows(10000))} />
        <Button id="add" text="Append 1,000 rows" onClick={() => setRows((current) => [...current, ...buildRows(1000)])} />
        <Button id="update" text="Update every 10th row" onClick={updateEveryTenth} />
        <Button id="clear" text="Clear" onClick={() => setRows([])} />
        <Button id="swaprows" text="Swap Rows" onClick={swapRows} />
      </div>
      <table class="table">
        <tbody id="tbody">
          <For each={rows()}>
            {(row) => (
              <tr class={{ danger: isSelected[row.id] === true }}>
                <td class="col-md-1">{row.id}</td>
                <td class="col-md-4">
                  <a onClick={() => setSelected(row.id)}>{row.label()}</a>
                </td>
                <td class="col-md-1">
                  <a class="remove" onClick={() => setRows((current) => current.filter((r) => r.id !== row.id))}>
                    x
                  </a>
                </td>
                <td class="col-md-6" />
              </tr>
            )}
          </For>
        </tbody>
      </table>
    </div>
  );
};

render(() => <App />, document.getElementById("main"));
