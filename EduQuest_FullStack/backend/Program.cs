using System.Text;
using System.Text.Json.Serialization;
using EduQuest.Api.Data;
using EduQuest.Api.Hubs;
using EduQuest.Api.Models;
using EduQuest.Api.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers().AddJsonOptions(o => {
    o.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter());
    o.JsonSerializerOptions.PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.SnakeCaseLower;
});
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c => {
    c.CustomSchemaIds(t => (t.FullName ?? t.Name).Replace("+", "."));
    c.ResolveConflictingActions(apis => apis.First());
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme {
        Description = "Đăng nhập qua POST /api/auth/login, sao chép token và nhập vào đây.",
        Name = "Authorization", In = ParameterLocation.Header,
        Type = SecuritySchemeType.Http, Scheme = "bearer", BearerFormat = "JWT"
    });
    c.AddSecurityRequirement(new OpenApiSecurityRequirement {
        { new OpenApiSecurityScheme {
            Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" }
          }, Array.Empty<string>() }
    });
});
builder.Services.AddDbContext<AppDbContext>(o => o.UseSqlite(builder.Configuration.GetConnectionString("Default")));
builder.Services.AddScoped<TokenService>();
builder.Services.AddSingleton<QuizDocumentParser>();
builder.Services.AddSingleton<RoomGameService>();
builder.Services.AddHostedService<RoomGameWorker>();
builder.Services.AddSignalR();
var jwtKey = builder.Configuration["Jwt:Key"]!;
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(o => {
    o.Events = new JwtBearerEvents
    {
        OnMessageReceived = context =>
        {
            // SignalR Flutter clients send the bearer token as access_token on the hub request.
            var accessToken = context.Request.Query["access_token"];
            if (!string.IsNullOrEmpty(accessToken) && context.HttpContext.Request.Path.StartsWithSegments("/hubs/rooms"))
                context.Token = accessToken;
            return Task.CompletedTask;
        }
    };
    o.TokenValidationParameters = new TokenValidationParameters {
        ValidateIssuer = true, ValidIssuer = builder.Configuration["Jwt:Issuer"],
        ValidateAudience = true, ValidAudience = builder.Configuration["Jwt:Audience"],
        ValidateLifetime = true, ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
        ClockSkew = TimeSpan.FromSeconds(30)
    };
});
builder.Services.AddAuthorization();
builder.Services.AddCors(o => o.AddPolicy("Flutter", p => p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));
var app = builder.Build();
using (var scope = app.Services.CreateScope()) {
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await db.Database.EnsureCreatedAsync();
    await SchemaCompatibility.EnsureAsync(db);
    await SeedData.InitializeAsync(db);
}
app.UseCors("Flutter");
if (app.Environment.IsDevelopment()) { app.UseSwagger(); app.UseSwaggerUI(); }
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapHub<RoomHub>("/hubs/rooms");
app.MapGet("/", () => Results.Ok(new { name = "EduQuest API", status = "ok", docs = "/swagger" }));
app.Run();
