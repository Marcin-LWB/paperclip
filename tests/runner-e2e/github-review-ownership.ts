import type { ChatEndpoint } from "../../packages/shared/src/types/chat-channels.js";
import { ConnectionFailure } from "./connection-config.js";
import type { GitHubReviewJourneyConfig } from "./github-review-config.js";

export interface GitHubJourneyResources {
  endpointId?: string; pullNumber?: number; branch: string; appName: string;
  appId?: string; appSlug?: string; appSettingsUrl?: string; installationSettingsUrl?: string;
  issueId?: string; runIds: string[];
}

/** Bind cleanup to GitHub-confirmed identity on this attempt's owned endpoint. */
export function captureOwnedGitHubApp(resources: GitHubJourneyResources, endpoint: ChatEndpoint, config: GitHubReviewJourneyConfig) {
  if (!endpoint.botExternalId || endpoint.setup.github?.registrationStatus !== "completed") return false;
  const app = endpoint.setup.github;
  if (endpoint.id !== resources.endpointId || endpoint.companyId !== config.target.companyId || endpoint.provider !== "github"
    || endpoint.assignedAgentId !== config.agent.id || endpoint.botLabel !== resources.appName
    || !/^[1-9][0-9]*$/.test(endpoint.botExternalId) || !app.appSlug || !/^[a-z0-9-]+$/.test(app.appSlug)
    || endpoint.botUsername !== `${app.appSlug}[bot]` || app.appOwnerType !== config.github.ownerType
    || app.appOwnerLogin?.toLowerCase() !== config.github.appOwner.toLowerCase()
    || (resources.appId && resources.appId !== endpoint.botExternalId)
    || (resources.appSlug && resources.appSlug !== app.appSlug)) throw new ConnectionFailure("owned_github_app_binding_mismatch");
  resources.appId = endpoint.botExternalId;
  resources.appSlug = app.appSlug;
  const owner = encodeURIComponent(app.appOwnerLogin!);
  resources.appSettingsUrl = app.appOwnerType === "organization"
    ? `https://github.com/organizations/${owner}/settings/apps/${app.appSlug}`
    : `https://github.com/settings/apps/${app.appSlug}`;
  // Installation management is a different resource. Uninstalling is not proof
  // that the owned App registration was deleted.
  resources.installationSettingsUrl = app.managementUrl;
  return true;
}
