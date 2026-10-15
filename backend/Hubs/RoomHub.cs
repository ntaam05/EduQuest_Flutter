using System.Security.Claims;
using EduQuest.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace EduQuest.Api.Hubs;

[Authorize]
public sealed class RoomHub(RoomGameService games) : Hub
{
    private int UserId => int.TryParse(Context.User?.FindFirstValue(ClaimTypes.NameIdentifier), out var id)
        ? id : throw new HubException("Không xác định được tài khoản.");

    public async Task<object> JoinRoom(string roomId)
    {
        var snapshot = await games.GetSnapshotAsync(roomId, UserId);
        if (snapshot is null) throw new HubException("Không tìm thấy phòng hoặc bạn không phải thành viên.");
        await Groups.AddToGroupAsync(Context.ConnectionId, RoomGameService.GroupName(roomId));
        await Clients.Group(RoomGameService.GroupName(roomId)).SendAsync("RoomUpdated", await games.GetRoomOverviewAsync(roomId));
        return snapshot;
    }

    public async Task<object> SubmitAnswer(string roomId, int questionId, int selectedAnswerIndex)
    {
        try
        {
            return await games.SubmitAnswerAsync(roomId, UserId, questionId, selectedAnswerIndex);
        }
        catch (InvalidOperationException ex)
        {
            throw new HubException(ex.Message);
        }
    }

    public Task LeaveRoom(string roomId) => Groups.RemoveFromGroupAsync(Context.ConnectionId, RoomGameService.GroupName(roomId));
}
