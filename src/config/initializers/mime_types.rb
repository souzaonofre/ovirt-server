# Be sure to restart your server when you modify this file.

# Add new mime types for use in respond_to blocks:
# Mime::Type.register "text/richtext", :rtf
# Mime::Type.register_alias "text/html", :iphone

# Workaround for rack gem + rails gem 2.3.2 on a same machine
# See https://rails.lighthouseapp.com/projects/8994/tickets/2784-private-method-split-called-for-mimetype0x226f618
class Mime::Type
  delegate :split, :to => :to_s
end
