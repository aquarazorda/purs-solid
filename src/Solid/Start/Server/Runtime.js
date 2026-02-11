import * as Data_Maybe from "../Data.Maybe/index.js";

const tuple = (left) => (right) => ({ value0: left, value1: right });

const normalizeMethod = (value) => {
  if (typeof value !== "string") {
    return "GET";
  }

  return value.toUpperCase();
};

const normalizePath = (value) => {
  if (typeof value !== "string" || value.length === 0) {
    return "/";
  }

  return value;
};

const normalizePairs = (value) => {
  if (Array.isArray(value)) {
    return value.map((entry) => {
      if (entry != null && typeof entry === "object" && "value0" in entry && "value1" in entry) {
        return tuple(String(entry.value0))(String(entry.value1));
      }

      if (Array.isArray(entry) && entry.length >= 2) {
        return tuple(String(entry[0]))(String(entry[1]));
      }

      return tuple("invalid")("invalid");
    });
  }

  if (value != null && typeof value === "object") {
    return Object.entries(value).map(([key, pairValue]) => tuple(String(key))(String(pairValue)));
  }

  return [];
};

const normalizeBody = (value) => {
  if (value == null) {
    return Data_Maybe.Nothing.value;
  }

  return Data_Maybe.Just.create(String(value));
};

export const readRuntimeMethod = (request) => () => normalizeMethod(request?.method);

export const readRuntimePath = (request) => () => normalizePath(request?.path);

export const readRuntimeHeaders = (request) => () => normalizePairs(request?.headers);

export const readRuntimeQuery = (request) => () => normalizePairs(request?.query);

export const readRuntimeBody = (request) => () => normalizeBody(request?.body);

export const mkRuntimeResponseImpl = (status) => (headers) => (bodyKind) => (body) => ({
  status,
  headers,
  bodyKind,
  body
});

export const runtimeResponseStatus = (response) => {
  if (response == null || typeof response.status !== "number") {
    return 500;
  }

  return response.status;
};

export const runtimeResponseHeaders = (response) => {
  if (response == null) {
    return [];
  }

  return normalizePairs(response.headers);
};

export const runtimeResponseBody = (response) => {
  if (response == null || typeof response.body !== "string") {
    return "";
  }

  return response.body;
};

export const runtimeResponseBodyKind = (response) => {
  if (response == null || typeof response.bodyKind !== "string") {
    return "empty";
  }

  return response.bodyKind;
};
