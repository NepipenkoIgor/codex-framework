# SignalR (.NET)

```csharp
// Strongly-typed hub
public interface IChatClient
{
    Task ReceiveMessage(ChatMessage message);
    Task UserJoined(string userId, string displayName);
    Task UserLeft(string userId);
    Task PresenceUpdate(PresenceInfo presence);
    Task TypingStarted(string userId);
    Task TypingStopped(string userId);
}

[Authorize]
public class ChatHub : Hub<IChatClient>
{
    private readonly IPresenceService _presence;
    private readonly IMessageService _messages;

    public override async Task OnConnectedAsync()
    {
        var userId = Context.UserIdentifier!;
        await _presence.SetOnline(userId);
        await Groups.AddToGroupAsync(Context.ConnectionId, $"user:{userId}");
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        var userId = Context.UserIdentifier!;
        await _presence.SetOffline(userId);
    }

    public async Task JoinRoom(string roomId)
    {
        var userId = Context.UserIdentifier!;
        if (!await _messages.CanJoinRoom(userId, roomId))
            throw new HubException("Access denied");

        await Groups.AddToGroupAsync(Context.ConnectionId, roomId);
        await Clients.Group(roomId).UserJoined(userId, Context.User!.Identity!.Name!);
    }

    public async Task SendMessage(string roomId, string text)
    {
        var userId = Context.UserIdentifier!;
        var message = await _messages.Save(roomId, userId, text);
        await Clients.Group(roomId).ReceiveMessage(message);
    }

    public async Task StartTyping(string roomId)
    {
        await Clients.OthersInGroup(roomId).TypingStarted(Context.UserIdentifier!);
    }
}

// Startup configuration
builder.Services.AddSignalR()
    .AddStackExchangeRedis(connectionString, options =>
    {
        options.Configuration.ChannelPrefix = RedisChannel.Literal("ChatHub");
    });

app.MapHub<ChatHub>("/hubs/chat");
```

## Key SignalR Features

- Strongly-typed hubs with `IClient` interface -- compile-time safety
- Groups for rooms/channels
- `[Authorize]` on Hub and methods for auth
- Redis backplane for scale-out: `AddStackExchangeRedis()`
- `OnConnectedAsync` / `OnDisconnectedAsync` for presence
- `Context.UserIdentifier` from JWT claims for user identification
- Automatic transport negotiation (WebSocket -> SSE -> Long Polling)
