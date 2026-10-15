using System.Data.Common;
using Microsoft.EntityFrameworkCore;

namespace EduQuest.Api.Data;

/// <summary>Small additive compatibility step for databases created by earlier EduQuest bundles.
/// New installations are still created by EnsureCreated; existing room tables receive the new game fields.
/// </summary>
public static class SchemaCompatibility
{
    public static async Task EnsureAsync(AppDbContext db, CancellationToken cancellationToken = default)
    {
        await db.Database.OpenConnectionAsync(cancellationToken);
        try
        {
            var connection = db.Database.GetDbConnection();
            await AddColumnIfMissingAsync(connection, "StudyRooms", "RoundDurationSeconds", "INTEGER NOT NULL DEFAULT 25", cancellationToken);
            await AddColumnIfMissingAsync(connection, "StudyRooms", "CurrentQuestionIndex", "INTEGER NOT NULL DEFAULT -1", cancellationToken);
            await AddColumnIfMissingAsync(connection, "StudyRooms", "CurrentRoundNumber", "INTEGER NOT NULL DEFAULT 0", cancellationToken);
            await AddColumnIfMissingAsync(connection, "StudyRooms", "CurrentRoundStartedAt", "TEXT NULL", cancellationToken);
            await AddColumnIfMissingAsync(connection, "StudyRooms", "RoundResultsShownAt", "TEXT NULL", cancellationToken);
            await AddColumnIfMissingAsync(connection, "StudyRooms", "FinishedAt", "TEXT NULL", cancellationToken);

            await ExecuteAsync(connection, """
                CREATE TABLE IF NOT EXISTS "RoomAnswers" (
                    "Id" INTEGER NOT NULL CONSTRAINT "PK_RoomAnswers" PRIMARY KEY AUTOINCREMENT,
                    "RoomId" TEXT NOT NULL,
                    "QuestionId" INTEGER NOT NULL,
                    "UserId" INTEGER NOT NULL,
                    "SelectedAnswerIndex" INTEGER NOT NULL,
                    "IsCorrect" INTEGER NOT NULL,
                    "Points" INTEGER NOT NULL,
                    "ElapsedMilliseconds" INTEGER NOT NULL,
                    "AnsweredAt" TEXT NOT NULL,
                    CONSTRAINT "FK_RoomAnswers_StudyRooms_RoomId" FOREIGN KEY ("RoomId") REFERENCES "StudyRooms" ("Id") ON DELETE CASCADE,
                    CONSTRAINT "FK_RoomAnswers_Questions_QuestionId" FOREIGN KEY ("QuestionId") REFERENCES "Questions" ("Id") ON DELETE CASCADE,
                    CONSTRAINT "FK_RoomAnswers_Users_UserId" FOREIGN KEY ("UserId") REFERENCES "Users" ("Id") ON DELETE CASCADE
                );
                """, cancellationToken);
            await ExecuteAsync(connection, "CREATE UNIQUE INDEX IF NOT EXISTS \"IX_RoomAnswers_RoomId_QuestionId_UserId\" ON \"RoomAnswers\" (\"RoomId\", \"QuestionId\", \"UserId\");", cancellationToken);
        }
        finally
        {
            await db.Database.CloseConnectionAsync();
        }
    }

    private static async Task AddColumnIfMissingAsync(DbConnection connection, string table, string column, string definition, CancellationToken cancellationToken)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = $"PRAGMA table_info(\"{table}\");";
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            if (string.Equals(reader.GetString(1), column, StringComparison.OrdinalIgnoreCase)) return;
        }
        await reader.DisposeAsync();
        await ExecuteAsync(connection, $"ALTER TABLE \"{table}\" ADD COLUMN \"{column}\" {definition};", cancellationToken);
    }

    private static async Task ExecuteAsync(DbConnection connection, string sql, CancellationToken cancellationToken)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = sql;
        await command.ExecuteNonQueryAsync(cancellationToken);
    }
}
