import { useLocation, useSearchParams } from "@solidjs/router";

const values = (raw) => (raw == null ? [] : Array.isArray(raw) ? raw : [raw]);

export const useSearchImpl = (fields) => ({ location: useLocation(), set: useSearchParams()[1], fields });

export const searchParams = (search) => () => {
  const record = {};
  for (const field of search.fields) record[field.name] = field.read(values(search.location.query[field.name]));
  return record;
};

export const setSearchImpl = (search, given, options) => {
  const params = {};
  for (const field of search.fields) {
    if (!(field.name in given)) continue;
    const written = field.write(given[field.name]);
    params[field.name] = written.length === 0 ? null : written.length === 1 ? written[0] : written;
  }
  search.set(params, options);
};
