export const sameRef = (left) => (right) =>
  left === right;

export const produceIncrementCount = (draft) => () => {
  draft.count = Number(draft.count) + 10;
};

export const mutateMutableCount = (draft) => () => {
  draft.count = Number(draft.count) + 2;
};
