require 'telegram/bot'

token = ENV['TELEGRAM_BOT_TOKEN']
users = {}
keyboard = [
  %w[AC + -],
  %w[7 8 9],
  %w[4 5 6],
  %w[1 2 3],
  [' ', '0', '=']].map do |keys|
  keys.map do |key|
    Telegram::Bot::Types::InlineKeyboardButton.new(text: key, callback_data: key)
  end
end
markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: keyboard)

Telegram::Bot::Client.run(token) do |bot|
  bot.listen do |message|
    case message
    when Telegram::Bot::Types::CallbackQuery
      if current_user = users[message.from.id]
        message_data = nil
        if message.data =~ /^\d$/
          if current_user[:change_number]
            current_user[:change_number] = false
            current_user[:previous_number] = current_user[:current_number]
            message_data = message.data
          else
            if current_user[:current_number] == '0'
              message_data = message.data
            else
              message_data = current_user[:current_number] + message.data.to_s
            end
          end

          current_user[:current_number] = message_data
        elsif message.data == 'AC'
          current_user[:previous_number] = nil
          current_user[:current_operation] = nil
          current_user[:change_number] = false
          message_data = '0'
          next if message_data == current_user[:current_number]
          current_user[:current_number] = '0'
        elsif message.data == '+' || message.data == '-'
          current_user[:current_operation] = message.data
          current_user[:change_number] = true
        elsif message.data == '='
          if current_user[:current_operation] == '+'
            message_data = (current_user[:previous_number].to_i + current_user[:current_number].to_i).to_s
          elsif current_user[:current_operation] == '-'
            message_data = (current_user[:previous_number].to_i - current_user[:current_number].to_i).to_s
          end

          current_user[:previous_number] = nil
          current_user[:current_operation] = nil

          next if message_data == current_user[:current_number]
          current_user[:current_number] = message_data
        end

        bot.api.edit_message_text(
          chat_id: message.from.id,
          message_id: current_user[:message_id],
          text: message_data,
          reply_markup: markup
        ) unless message_data.nil?
      end
    when Telegram::Bot::Types::Message
      case message.text
      when '/start'
        users[message.from.id] = {}
        res = bot.api.send_message(
          chat_id: message.chat.id,
          text: '0',
          reply_markup: markup
        )

        if res['ok']
          users[message.from.id] = {
            message_id: res['result']['message_id'],
            current_number: '0'
          }
        end
      end
    end

    p users.inspect
  end
end
