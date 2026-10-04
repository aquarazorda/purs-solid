export const inputValue = (element) => () => element.value;

export const tagName = (element) => () => element.tagName;

export const documentTitle = () => document.title;

export const dispatch = (type) => (element) => () => element.dispatchEvent(new Event(type, { bubbles: true }));
