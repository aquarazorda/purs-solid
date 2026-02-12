import { element } from "#purs/Solid.Component/index.js";
import { appWithRoute } from "#purs/Examples.SolidStart.App/index.js";
import { routePathFromProps } from "../../_purs_route.js";

const routeSegments = [
  {
    "kind": "static",
    "value": "users"
  },
  {
    "kind": "param",
    "value": "id"
  }
];

export default function RoutePage(props) {
  const routePath = routePathFromProps(routeSegments, props);
  return element(appWithRoute(routePath))({});
}
