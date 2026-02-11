import * as Data_Either from "../Data.Either/index.js";
import * as Data_Maybe from "../Data.Maybe/index.js";

const STORIES_API_BASE = "https://node-hnapi.herokuapp.com";
const USERS_API_BASE = "https://hacker-news.firebaseio.com/v0";

const nothing = Data_Maybe.Nothing.value;

const just = (value) =>
  Data_Maybe.Just.create(value);

const toMaybeString = (value) => {
  if (typeof value === "string" && value.length > 0) {
    return just(value);
  }

  return nothing;
};

const toMaybeInt = (value) => {
  if (typeof value === "number" && Number.isFinite(value)) {
    return just(Math.trunc(value));
  }

  return nothing;
};

const asString = (value, fallback = "") => {
  if (typeof value === "string") {
    return value;
  }

  return fallback;
};

const asInt = (value, fallback = 0) => {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }

  return fallback;
};

const asArray = (value) =>
  Array.isArray(value) ? value : [];

const toErrorMessage = (error) => {
  if (typeof error === "string") {
    return error;
  }

  if (error instanceof Error && typeof error.message === "string") {
    return error.message;
  }

  return String(error);
};

const fetchJson = async (url) => {
  if (typeof fetch !== "function") {
    return Data_Either.Left.create("fetch is unavailable in current runtime");
  }

  try {
    const response = await fetch(url, {
      headers: {
        accept: "application/json",
      },
    });

    if (!response.ok) {
      return Data_Either.Left.create(`HTTP ${response.status}`);
    }

    return Data_Either.Right.create(await response.json());
  } catch (error) {
    return Data_Either.Left.create(toErrorMessage(error));
  }
};

const normalizeComment = (comment) => ({
  id: asInt(comment?.id),
  user: toMaybeString(comment?.user),
  timeAgo: asString(comment?.time_ago, "unknown"),
  content: asString(comment?.content, ""),
  comments: asArray(comment?.comments).map(normalizeComment),
});

const normalizeStory = (story) => ({
  id: asInt(story?.id),
  title: asString(story?.title, "Untitled"),
  points: toMaybeInt(story?.points),
  user: toMaybeString(story?.user),
  timeAgo: asString(story?.time_ago, "unknown"),
  commentsCount: asInt(story?.comments_count),
  storyType: asString(story?.type, "link"),
  url: toMaybeString(story?.url),
  domain: toMaybeString(story?.domain),
});

const normalizeStoryDetail = (story) => ({
  id: asInt(story?.id),
  title: asString(story?.title, "Untitled"),
  points: toMaybeInt(story?.points),
  user: toMaybeString(story?.user),
  timeAgo: asString(story?.time_ago, "unknown"),
  storyType: asString(story?.type, "link"),
  url: toMaybeString(story?.url),
  domain: toMaybeString(story?.domain),
  commentsCount: asInt(story?.comments_count),
  comments: asArray(story?.comments).map(normalizeComment),
});

const normalizeCreatedLabel = (createdSeconds) => {
  const created = asInt(createdSeconds);
  if (created <= 0) {
    return "unknown";
  }

  const date = new Date(created * 1000);
  if (Number.isNaN(date.getTime())) {
    return "unknown";
  }

  return date.toISOString().slice(0, 10);
};

const normalizeUser = (user) => ({
  id: asString(user?.id, "unknown"),
  created: asInt(user?.created),
  createdLabel: normalizeCreatedLabel(user?.created),
  karma: asInt(user?.karma),
  about: toMaybeString(user?.about),
});

export const fetchStoriesImpl = (feedSegment) => (page) => () => {
  const safePage =
    typeof page === "number" && Number.isFinite(page) && page > 0
      ? Math.trunc(page)
      : 1;
  const safeFeed =
    typeof feedSegment === "string" && feedSegment.length > 0
      ? feedSegment
      : "news";

  return fetchJson(`${STORIES_API_BASE}/${safeFeed}?page=${safePage}`).then(
    (result) => {
      if (result instanceof Data_Either.Left) {
        return result;
      }

      return Data_Either.Right.create(asArray(result.value0).map(normalizeStory));
    }
  );
};

export const fetchStoryImpl = (storyId) => () => {
  const safeStoryId =
    typeof storyId === "string" && storyId.length > 0
      ? storyId
      : "";

  if (safeStoryId.length === 0) {
    return Promise.resolve(Data_Either.Left.create("Missing story id"));
  }

  return fetchJson(`${STORIES_API_BASE}/item/${encodeURIComponent(safeStoryId)}`).then(
    (result) => {
      if (result instanceof Data_Either.Left) {
        return result;
      }

      return Data_Either.Right.create(normalizeStoryDetail(result.value0));
    }
  );
};

export const fetchUserImpl = (userId) => () => {
  const safeUserId =
    typeof userId === "string" && userId.length > 0
      ? userId
      : "";

  if (safeUserId.length === 0) {
    return Promise.resolve(Data_Either.Left.create("Missing user id"));
  }

  return fetchJson(`${USERS_API_BASE}/user/${encodeURIComponent(safeUserId)}.json`).then(
    (result) => {
      if (result instanceof Data_Either.Left) {
        return result;
      }

      if (result.value0 == null || typeof result.value0 !== "object") {
        return Data_Either.Left.create("User not found");
      }

      return Data_Either.Right.create(normalizeUser(result.value0));
    }
  );
};
