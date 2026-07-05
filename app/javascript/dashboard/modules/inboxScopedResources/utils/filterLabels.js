export function isResourceVisibleForInbox(resource, inboxId) {
  if (!resource.inbox_id) return true;
  if (!inboxId) return false;
  return resource.inbox_id === inboxId;
}

export function filterResourcesForInbox(resources, inboxId) {
  return resources.filter(resource =>
    isResourceVisibleForInbox(resource, inboxId)
  );
}

export function filterResourcesForUserInboxes(resources, inboxIds) {
  return resources.filter(
    resource => !resource.inbox_id || inboxIds.includes(resource.inbox_id)
  );
}

export function getInboxScopeLabel(resource, inboxes, t) {
  if (!resource.inbox_id) {
    return t('INBOX_SCOPED_RESOURCES.ALL_INBOXES');
  }
  return inboxes.find(inbox => inbox.id === resource.inbox_id)?.name || '—';
}

export const isLabelVisibleForInbox = isResourceVisibleForInbox;
export const filterLabelsForInbox = filterResourcesForInbox;
export const filterLabelsForUserInboxes = filterResourcesForUserInboxes;
export const filterCannedResponsesForInbox = filterResourcesForInbox;
