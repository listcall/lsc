# inspired by 'letter_opener' gem

require 'erb'

module DeliveryMethod
  class OpenerDm
    attr_accessor :settings

    def initialize(options = {})
      opts = {:location => Rails.root.join('tmp', 'opener')}
      self.settings = opts.merge(options)
    end

    def deliver!(mail)
      dev_log 'Starting Opener Sender'
      location = File.join(settings[:location], "#{Time.now.to_i}_#{Digest::SHA1.hexdigest(mail.encoded)[0..6]}")
      messages = OpenerMessage.rendered_messages(location, mail)
      Launchy.open("file:///#{URI.parse(URI.escape(messages.first.filepath))}")
      dev_log 'Message Sent'
      oid = mail.header['Outbound-ID'].try(:value)
      Pgr::Outbound.find(oid).try(:touch, :sent_at) if oid
    end
  end

  class OpenerMessage
    attr_reader :mail

    def initialize(location, mail, part = nil)
      @location = location
      @mail = mail
      @part = part
      @team_name   = @mail.from.first.split('@').last.split('.').first
      @attachments = []
    end

    def self.rendered_messages(location, mail)
      messages = []
      messages << new(location, mail, mail.html_part) if mail.html_part
      messages << new(location, mail, mail.text_part) if mail.text_part
      messages << new(location, mail) if messages.empty?
      messages.each(&:render)
      messages.sort
    end

    def render
      FileUtils.mkdir_p(@location)

      if mail.attachments.any?
        attachments_dir = File.join(@location, 'attachments')
        FileUtils.mkdir_p(attachments_dir)
        mail.attachments.each do |attachment|
          filename = attachment.filename.gsub(/[^\w.]/, '_')
          path = File.join(attachments_dir, filename)

          unless File.exist?(path) # true if other parts have already been rendered
            File.open(path, 'wb') { |f| f.write(attachment.body.raw_source) }
          end

          @attachments << [attachment.filename, "attachments/#{URI.escape(filename)}"]
        end
      end

      File.open(filepath, 'w') do |f|
        f.write ERB.new(template).result(binding)
      end
    end

    def template
      File.read(File.expand_path('../opener_message.html.erb', __FILE__))
    end

    def message_id
      @message_id ||= Array(@mail['message-id']).join(', ')
    end

    def filepath
      File.join(@location, "#{type}.html")
    end

    def content_type
      @part && @part.content_type || @mail.content_type
    end

    def body
      @body ||= begin
        body = (@part && @part.body || @mail.body).to_s

        mail.attachments.each do |attachment|
          body.gsub!(attachment.url, "attachments/#{attachment.filename}")
        end

        body
      end
    end

    def from
      @from ||= Array(@mail['from']).join(', ')
    end

    def sender
      @sender ||= Array(@mail['sender']).join(', ')
    end

    def to
      @to ||= Array(@mail['to']).join(', ')
    end

    def cc
      @cc ||= Array(@mail['cc']).join(', ')
    end

    def bcc
      @bcc ||= Array(@mail['bcc']).join(', ')
    end

    def reply_to
      @reply_to ||= Array(@mail['reply-to']).join(', ')
    end

    def type
      content_type =~ /html/ ? 'rich' : 'plain'
    end

    def encoding
      body.respond_to?(:encoding) ? body.encoding : 'utf-8'
    end

    def auto_link(text)
      text.gsub(URI.regexp(%W[https http])) do |link|
        "<a href=\"#{ link }\">#{ link }</a>"
      end
    end

    def h(content)
      CGI.escapeHTML(content)
    end

    def <=>(other)
      order = %w[rich plain]
      order.index(type) <=> order.index(other.type)
    end
  end
end
