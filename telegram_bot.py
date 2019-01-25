import telegram
import json
from telegram.ext import *
import logging

logging.basicConfig(format='%(asctime)s - %(name)s - %(levelname)s - %(message)s', level=logging.INFO)
updater = Updater('753901389:AAFvEFCn08-fUuNMiPZFLitFQP5q6WpkHnk')
dispatcher = updater.dispatcher
job_queue = updater.job_queue


def start(bot, update):
    reply_markup = telegram.ReplyKeyboardMarkup([['данные']], resize_keyboard=True)
    bot.send_message(chat_id=update.message.chat_id, text="Здравствуйте!", reply_markup = reply_markup)

def echo(bot, update):
    s = update.message.text
    if (s == 'данные'):
        with open("data_file.json", "r") as read_file:
            data = json.load(read_file)
            bot.send_message(update.message.chat_id, "Ускорение: " + "{0:0.2f}".format(str(data[0])), parse_mode=telegram.ParseMode.HTML)
            bot.send_message(update.message.chat_id, "Температура " + "{0:0.2f}".format(str(data[1])) + "\n Давление: " + "{0:0.2f}".format(str(data[2])) + "\n Высота: " + "{0:0.2f}".format(str(data[3])), parse_mode=telegram.ParseMode.HTML)


dispatcher.add_handler(MessageHandler(Filters.text, echo))
dispatcher.add_handler(CommandHandler('start', start))
updater.start_polling()
