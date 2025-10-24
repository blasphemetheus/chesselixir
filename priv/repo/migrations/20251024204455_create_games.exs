defmodule Chesselixir.Repo.Migrations.CreateGames do
  use Ecto.Migration

  def change do
    create table(:games, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :fen, :string, null: false
      add :status, :string, null: false, default: "playing"
      add :white_id, :uuid
      add :black_id, :uuid
      timestamps()
    end

    create table(:moves) do
      add :game_id, references(:games, type: :uuid, on_delete: :delete_all), null: false
      add :uci, :string, null: false
      add :san, :string
      add :fen_after, :string, null: false
      add :number, :integer
      timestamps()
    end

    create index(:moves, [:game_id])
  end
end
