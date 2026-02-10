import h from "solid-js/h";

export const component = (render) => {
  const wrapped = (props) =>
    render(props)();

  return wrapped;
};

export const element = (comp) => (props) =>
  h(comp, props);

export const elementKeyed = (comp) => (props) =>
  h(comp, props);
