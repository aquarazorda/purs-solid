import { isWrappable as solidIsWrappable } from "solid-js";

// Freeze atomic values so Solid doesn't proxy PureScript ADTs.

export const noPreparer = null;

export const atomicPreparer = (value) => {
  if (solidIsWrappable(value)) Object.freeze(value);
};

export const noFields = [];

export const consField = (name) => (preparer) => (tail) =>
  preparer === null ? tail : [{ name, preparer }, ...tail];

export const recordPreparer = (fields) => {
  if (fields.length === 0) return null;
  return (record) => {
    for (const field of fields) field.preparer(record[field.name]);
  };
};

export const arrayPreparer = (element) => {
  if (element === null) return null;
  return (array) => {
    for (const item of array) element(item);
  };
};
