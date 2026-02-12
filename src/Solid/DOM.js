import { createComponent as solidCreateComponent } from "solid-js";
import { Dynamic as solidDynamic } from "solid-js/web";

export const element = (tag) => (props) => (children) =>
  solidCreateComponent(solidDynamic, { component: tag, ...props, children });

export const element_ = (tag) => (children) =>
  solidCreateComponent(solidDynamic, { component: tag, children });
