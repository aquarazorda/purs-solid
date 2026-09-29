import { mapArray as solidMapArray, repeat as solidRepeat } from "solid-js";

export const mapArrayImpl = (list, mapItem) =>
  solidMapArray(list, (item, index) => mapItem(item, index));

export const mapArrayUnkeyedImpl = (list, mapItem) =>
  solidMapArray(list, (item, index) => mapItem(item, index), { keyed: false });

export const mapArrayByImpl = (key, list, mapItem) =>
  solidMapArray(list, (item, index) => mapItem(item, index), { keyed: (item) => key(item) });

export const repeatImpl = (count, mapIndex) =>
  solidRepeat(count, (index) => mapIndex(index)());
