import { mapArray } from "solid-js";

export { repeat as repeatImpl } from "solid-js";

export const mapArrayImpl = (keyed, list, mapItem) => mapArray(list, mapItem, { keyed });
