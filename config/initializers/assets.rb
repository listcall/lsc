# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.1'

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path
# Add Yarn node_modules folder to the asset load path.
Rails.application.config.assets.paths << Rails.root.join('node_modules')

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.
# Rails.application.config.assets.precompile += %w( admin.js admin.css )

js_prefix = 'app/assets/javascripts/'
Rails.application.config.assets.precompile += %w(*.png *.jpg *.jpeg *.gif)
Rails.application.config.assets.precompile += Dir.glob("#{js_prefix}**/all_*.js").map {|x| x.gsub(js_prefix, '')}
Rails.application.config.assets.precompile += Dir.glob("#{js_prefix}*.js.coffee").map {|x| x.gsub(js_prefix, '').gsub('.coffee','')}
Rails.application.config.assets.paths << Rails.root.join('vendor/assets/javascripts')
