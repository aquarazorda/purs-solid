const API = "https://hacker-news.firebaseio.com/v0";
const PAGE_SIZE = 30;
const MAX_COMMENTS = 200;

const getJson = async (path) => {
  const response = await fetch(`${API}/${path}.json`);
  if (!response.ok) throw new Error(`Hacker News API: ${response.status}`);
  return response.json();
};

const toStory = (item) => ({
  id: item.id,
  title: item.title ?? "",
  url: item.url ?? null,
  points: item.score ?? 0,
  by: item.by ?? null,
  time: item.time ?? 0,
  comments: item.descendants ?? 0,
});

export async function storiesOnServer({ feed, page }) {
  "use server";
  const ids = await getJson(feed);
  const slice = ids.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);
  const items = await Promise.all(slice.map((id) => getJson(`item/${id}`)));
  return items.filter((item) => item != null && !item.deleted).map(toStory);
}

export async function storyOnServer(id) {
  "use server";
  const item = await getJson(`item/${id}`);
  if (item == null) return null;
  const comments = [];
  let frontier = (item.kids ?? []).map((kid) => ({ kid, parent: item.id }));
  while (frontier.length > 0 && comments.length < MAX_COMMENTS) {
    const batch = frontier.slice(0, MAX_COMMENTS - comments.length);
    frontier = [];
    const loaded = await Promise.all(batch.map(({ kid }) => getJson(`item/${kid}`)));
    loaded.forEach((comment, index) => {
      if (comment == null || comment.deleted || comment.dead) return;
      comments.push({ id: comment.id, parent: batch[index].parent, by: comment.by ?? null, html: comment.text ?? "", time: comment.time ?? 0 });
      for (const kid of comment.kids ?? []) frontier.push({ kid, parent: comment.id });
    });
  }
  return { story: toStory(item), comments };
}

export async function userOnServer(id) {
  "use server";
  const found = await getJson(`user/${encodeURIComponent(id)}`);
  if (found == null) return null;
  return { id: found.id, created: found.created ?? 0, karma: found.karma ?? 0, about: found.about ?? null };
}
