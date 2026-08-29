# Redmine 初期ブートストラップ
#
# 実行:
#   docker exec -i \
#     -e SECRET_KEY_BASE="$(grep '^REDMINE_SECRET_KEY_BASE=' ... )" \
#     gst-redmine bin/rails runner - < infra/seed/redmine_bootstrap.rb
#   （詳細は infra/README.md）
#
# 目的:
#   1. デフォルトデータ（トラッカー / ステータス / 優先度 / ロール）を投入
#   2. REST API を有効化
#   3. admin の強制パスワード変更フラグを解除
#   4. admin の API キーを取得して出力（Redmine が生成した値。固定はしない）
#
# 注意:
#   - Redmine の Token モデルは値を自前生成するため、API キーの固定は不可。
#     このスクリプトが出力する "admin API key = ..." を控え、
#     seed 実行時の REDMINE_SEED_API_KEY と AI 実行時の REDMINE_API_KEY に使う。
#   - production 環境で runner を動かすため SECRET_KEY_BASE を exec に渡すこと
#     （docker exec は entrypoint を経由せず REDMINE_SECRET_KEY_BASE を解釈しない）。

# 1. デフォルトデータ
require 'redmine/default_data/loader'
if Redmine::DefaultData::Loader.no_data?
  Redmine::DefaultData::Loader.load('en')
  puts '[bootstrap] default data loaded'
else
  puts '[bootstrap] default data already present'
end

# 2. REST API
Setting.rest_api_enabled = '1'
Setting.jsonp_enabled = '1'
puts "[bootstrap] rest_api_enabled = #{Setting.rest_api_enabled}"

# 3. admin
admin = User.find_by_login('admin') or abort 'admin ユーザーが見つからない'
admin.must_change_passwd = false
admin.save!(validate: false)
puts "[bootstrap] admin.must_change_passwd = #{admin.must_change_passwd}"

# 4. API キー（無ければ生成して永続化。次回以降は同じ値）
api_key = admin.api_key
puts "[bootstrap] admin API key = #{api_key}"
puts '[bootstrap] done'
