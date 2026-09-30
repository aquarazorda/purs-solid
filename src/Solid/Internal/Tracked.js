// `Accessor` is a zero-argument function, like `Effect`: reading is calling.
export const mapImpl = (f) => (accessor) => () => f(accessor());

export const applyImpl = (accessorF) => (accessor) => () => accessorF()(accessor());

export const pureImpl = (value) => () => value;

export const bindImpl = (accessor) => (f) => () => f(accessor())();
