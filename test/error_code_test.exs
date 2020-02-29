defmodule Tds.Ecto.ErrorCodeTest do
  use ExUnit.Case

  @constraint_error_code 2627
  @constraint_message "Violation of UNIQUE KEY constraint 'unique_posts_uuid'. Cannot insert duplicate key in object 'dbo.posts'. The duplicate key value is (64881c1c-be4f-4781-9461-b885e2c8ea49"

  @index_error_code 2601
  @index_message "Cannot insert duplicate key row in object 'dbo.posts' with unique index 'posts_uuid_index'.The duplicate key value is (64881c1c-be4f-4781-9461-b885e2c8ea49)"

  @foreign_key_code 547
  @foreign_key_message ~s/The INSERT statement conflicted with the FOREIGN KEY constraint "posts_users_post_id_fkey". The conflict occurred in database "ecto_test", table "dbo.posts", column 'id'./

  @check_code 547
  @check_message ~s/The INSERT statement conflicted with the CHECK constraint "CK_Constrain_visits_123". The conflict occurred in database "ecto_test", table "dbo.posts", column 'visits'./

  @tag :latest
  test "get_constraint_violations returns the expected unique constraint name" do
    result = Tds.Ecto.ErrorCode.get_constraint_violations(@constraint_error_code, @constraint_message)
    assert result[:unique] == "unique_posts_uuid"
  end

  @tag :latest
  test "get_constraint_violations returns the expected index name" do
    result = Tds.Ecto.ErrorCode.get_constraint_violations(@index_error_code, @index_message)
    assert result[:unique] == "posts_uuid_index"
  end

  @tag :latest
  test "get_constraint_violations returns the expected foreign_key name" do
    result = Tds.Ecto.ErrorCode.get_constraint_violations(@foreign_key_code, @foreign_key_message)
    assert result[:foreign_key] == "posts_users_post_id_fkey"
  end

  @tag :latest
  test "get_constraint_violations returns the expected check name" do
    result = Tds.Ecto.ErrorCode.get_constraint_violations(@check_code, @check_message)
    assert result[:check] == "CK_Constrain_visits_123"
  end
end
