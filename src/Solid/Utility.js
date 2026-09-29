import { mapArray } from "solid-js";

export { mapArray as mapArrayImpl, repeat as repeatImpl } from "solid-js";

export const mapArrayUnkeyedImpl = (list, mapItem) => mapArray(list, mapItem, { keyed: false });

export const mapArrayByImpl = (key, list, mapItem) => mapArray(list, mapItem, { keyed: key });
