import { isWrappable as solidIsWrappable } from "solid-js";

// Preparers freeze atomic values so Solid stores them as-is (a frozen object is
// never proxied). Solid 2 proxies user class instances, which would break
// PureScript pattern matching on ADTs. `null` means nothing to prepare.

export const atomicPreparer = (value) => {
  if (solidIsWrappable(value)) Object.freeze(value);
};

export const recordPreparer = (fields) => {
  const active = fields.filter((field) => field.preparer !== null);
  if (active.length === 0) return null;
  return (record) => {
    for (const field of active) field.preparer(record[field.name]);
  };
};

export const arrayPreparer = (element) => {
  if (element === null) return null;
  return (array) => {
    for (const item of array) element(item);
  };
};

