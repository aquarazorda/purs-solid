import * as Data_Maybe from "../Data.Maybe/index.js";

const tuple = (left) => (right) => ({ value0: left, value1: right });

const hasRequestCtor = () => typeof Request !== "undefined";
const hasHeadersCtor = () => typeof Headers !== "undefined";
const hasResponseCtor = () => typeof Response !== "undefined";
const hasReadableStreamCtor = () => typeof ReadableStream !== "undefined";
const hasTextEncoderCtor = () => typeof TextEncoder !== "undefined";

const isWebRequest = (value) => hasRequestCtor() && value instanceof Request;
const isWebHeaders = (value) => hasHeadersCtor() && value instanceof Headers;
const isWebResponse = (value) => hasResponseCtor() && value instanceof Response;

const parseUrl = (rawUrl) => {
  if (typeof rawUrl !== "string" || rawUrl.length === 0) {
    return null;
  }

  try {
    return new URL(rawUrl, "http://localhost");
  } catch {
    return null;
  }
};

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
  if (isWebHeaders(value)) {
    return Array.from(value.entries()).map(([key, pairValue]) => tuple(String(key))(String(pairValue)));
  }

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

const bodyTextFromRequest = async (request) => {
  if (!isWebRequest(request)) {
    return normalizeBody(request?.body);
  }

  if (request.method === "GET" || request.method === "HEAD") {
    return Data_Maybe.Nothing.value;
  }

  try {
    const text = await request.clone().text();
    return text === "" ? Data_Maybe.Nothing.value : Data_Maybe.Just.create(text);
  } catch {
    return Data_Maybe.Nothing.value;
  }
};

const inferBodyKind = (response) => {
  if (!isWebResponse(response)) {
    return "empty";
  }

  const contentType = response.headers.get("content-type") ?? "";

  if (contentType.startsWith("application/json")) {
    return "json";
  }

  if (contentType.startsWith("text/html")) {
    return "html";
  }

  if (contentType.startsWith("text/")) {
    return "text";
  }

  if (response.body != null) {
    return "stream";
  }

  return "empty";
};

const toResponseInitHeaders = (headers) =>
  normalizePairs(headers).map((entry) => [entry.value0, entry.value1]);

const normalizeStreamChunks = (chunks, body) => {
  if (Array.isArray(chunks)) {
    return chunks.map((chunk) => String(chunk));
  }

  if (typeof body === "string" && body.length > 0) {
    return [body];
  }

  return [];
};

const toStreamBody = (chunks) => {
  if (!hasReadableStreamCtor()) {
    return chunks.join("");
  }

  if (hasTextEncoderCtor()) {
    const encoder = new TextEncoder();
    return new ReadableStream({
      start(controller) {
        for (const chunk of chunks) {
          controller.enqueue(encoder.encode(chunk));
        }
        controller.close();
      },
    });
  }

  return new ReadableStream({
    start(controller) {
      for (const chunk of chunks) {
        controller.enqueue(chunk);
      }
      controller.close();
    },
  });
};

const withRuntimeBodyMeta = (response, bodyKind, bodyText, streamChunks) => {
  Object.defineProperty(response, "__pursSolidBodyKind", {
    value: bodyKind,
    enumerable: false,
    configurable: true,
  });

  Object.defineProperty(response, "__pursSolidBodyText", {
    value: bodyText,
    enumerable: false,
    configurable: true,
  });

  Object.defineProperty(response, "__pursSolidStreamChunks", {
    value: streamChunks,
    enumerable: false,
    configurable: true,
  });

  return response;
};

export const readRuntimeMethod = (request) => () => {
  if (isWebRequest(request)) {
    return normalizeMethod(request.method);
  }

  return normalizeMethod(request?.method);
};

export const readRuntimePath = (request) => () => {
  if (isWebRequest(request)) {
    const parsed = parseUrl(request.url);
    return parsed == null ? "/" : normalizePath(parsed.pathname);
  }

  if (typeof request?.path === "string") {
    return normalizePath(request.path);
  }

  const parsed = parseUrl(request?.url);
  return parsed == null ? "/" : normalizePath(parsed.pathname);
};

export const readRuntimeHeaders = (request) => () => {
  if (isWebRequest(request)) {
    return normalizePairs(request.headers);
  }

  return normalizePairs(request?.headers);
};

export const readRuntimeQuery = (request) => () => {
  if (isWebRequest(request)) {
    const parsed = parseUrl(request.url);
    if (parsed == null) {
      return [];
    }

    return Array.from(parsed.searchParams.entries()).map(([key, value]) => tuple(String(key))(String(value)));
  }

  if (request?.query != null) {
    return normalizePairs(request.query);
  }

  const parsed = parseUrl(request?.url);
  if (parsed == null) {
    return [];
  }

  return Array.from(parsed.searchParams.entries()).map(([key, value]) => tuple(String(key))(String(value)));
};

export const readRuntimeBody = (request) => () => normalizeBody(request?.body);

export const readRuntimeBodyAsync = (request) => () =>
  bodyTextFromRequest(request);

export const mkRuntimeResponseImpl = (status) => (headers) => (bodyKind) => (body) => (streamChunks) => {
  const normalizedStreamChunks = normalizeStreamChunks(streamChunks, body);

  if (!hasResponseCtor()) {
    return {
      status,
      headers,
      bodyKind,
      body,
      streamChunks: normalizedStreamChunks,
    };
  }

  const responseBody = (() => {
    if (bodyKind === "empty") {
      return null;
    }

    if (bodyKind === "stream") {
      return toStreamBody(normalizedStreamChunks);
    }

    return body;
  })();

  const response = new Response(responseBody, {
    status,
    headers: toResponseInitHeaders(headers),
  });

  return withRuntimeBodyMeta(response, bodyKind, body, normalizedStreamChunks);
};

export const runtimeResponseStatus = (response) => {
  if (isWebResponse(response)) {
    return response.status;
  }

  if (response == null || typeof response.status !== "number") {
    return 500;
  }

  return response.status;
};

export const runtimeResponseHeaders = (response) => {
  if (isWebResponse(response)) {
    return normalizePairs(response.headers);
  }

  if (response == null) {
    return [];
  }

  return normalizePairs(response.headers);
};

export const runtimeResponseBody = (response) => {
  if (isWebResponse(response)) {
    if (typeof response.__pursSolidBodyText === "string") {
      return response.__pursSolidBodyText;
    }

    return "";
  }

  if (response == null || typeof response.body !== "string") {
    return "";
  }

  return response.body;
};

export const runtimeResponseBodyKind = (response) => {
  if (isWebResponse(response)) {
    if (typeof response.__pursSolidBodyKind === "string") {
      return response.__pursSolidBodyKind;
    }

    return inferBodyKind(response);
  }

  if (response == null || typeof response.bodyKind !== "string") {
    return "empty";
  }

  return response.bodyKind;
};

export const runtimeResponseStreamChunks = (response) => {
  if (isWebResponse(response)) {
    if (Array.isArray(response.__pursSolidStreamChunks)) {
      return response.__pursSolidStreamChunks;
    }

    return [];
  }

  if (!Array.isArray(response?.streamChunks)) {
    return [];
  }

  return response.streamChunks.map((chunk) => String(chunk));
};

export const runtimeResponseIsWeb = (response) =>
  isWebResponse(response);
