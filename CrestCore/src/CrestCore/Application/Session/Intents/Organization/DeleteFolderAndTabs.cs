using CrestCore.Application;

namespace CrestCore.Contracts;

/// Deletes a folder, the folders inside it and every tab they hold, as
/// `DeleteTabs` deletes tabs. Refused with `SelectionChanged` when the folder
/// holds other tabs than `MemberTabIds`, the ones the window saw.
public sealed record DeleteFolderAndTabs(Guid WorkspaceId, Guid WindowId, Guid SpaceId, Guid FolderId, IReadOnlyList<Guid> MemberTabIds)
    : SessionIntent(WorkspaceId) {
    #region Actions - Session

    internal override SessionEdit? Edit(NativeSessionAuthority workspace, SessionTurn turn) {
        var batch = workspace.Selecting(turn.Basis, WindowId, SpaceId, new([], [FolderId], MemberTabIds));
        batch.FollowUp.ShowTab(batch.Space.Id, batch.Edited.DeleteFolderAndTabs(batch.Selected, batch.Shown, batch.Fallback(), turn.Now));
        return batch.Result(turn.Basis, SyncStaging.BatchDeletion);
    }

    #endregion
}
