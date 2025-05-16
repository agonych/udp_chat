"""
This module implements the AI prompt and response generation functions for the
chat application.

OpenAI and Ollama are supported.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

from openai import OpenAI
import ollama

def build_chat_prompt(messages, user, content):
    """
    Build a chat prompt for the AI model.
    :param messages: List of messages in the chat.
    :param user: Name of the user to reply as.
    :param content: Content to improve (optional).
    :return: List of messages formatted for the AI model.
    """
    prompt = [
        {
            "role": "system",
            "content":
                "You are participating in a group chat. Your goal is to respond "
                 f"as if you are '{user}', using a casual, human-like, "
                 f"friendly tone. "

        }
    ]
    for m in messages:
        prompt.append({
            "role": "user",
            "content": f"{m['sender_name']}: {m['content']}"
        })
    if content:
        prompt.append({
            "role": "user",
            "content": (
                f"As {user}, you're planning to send this message: '{content}'. "
                "Improve it to make it sound more natural, accurate, and casual in this group chat context."
            )
        })
    else:
        prompt.append({
            "role": "user",
            "content": (
                f"Continue the chat as if you are {user}. "
                "Craft the next message that fits naturally into the "
                "conversation, something user would like to say next. Do not "
                "mention the name of the user you are pretending to be in "
                "your response. Do not use long paragraphs, lists, or formal "
                "language. Do not introduce yourself or sign messages. Do not put your answer in quotes or brackets."
            )
        })
    return prompt

def gtp_get_ai_response(messages, user, content, model="gpt-3.5-turbo"):
    """
    Get a chat response from OpenAI's GPT-3.5 Turbo model.
    :param messages: List of messages in the chat.
    :param user: Name of the user to reply as.
    :param content: Content to improve (optional).
    :param model: The OpenAI model to use (default is "gpt-3.5-turbo").
    :return: AI generated response.
    """
    prompt = build_chat_prompt(messages, user, content)
    try:
        client = OpenAI()
        response = client.chat.completions.create(model=model, messages=prompt)
        return response.choices[0].message.content.strip().strip("\"'").strip()
    except Exception as e:
        print("AI generation failed:", e)
        return None


def ollama_get_ai_response(messages, user, content, model="mistral"):
    """
    Get a chat response from a local Ollama model.
    :param messages: List of messages in the chat.
    :param user: Name of the user to reply as.
    :param content: Content to improve (optional).
    :param model: The local Ollama model name (default is "mistral").
    :return: AI generated response.
    """
    prompt = build_chat_prompt(messages, user, content)
    try:
        response = ollama.chat(model=model, messages=prompt)
        return response['message']['content'].strip().strip("\"'").strip()
    except Exception as e:
        print("AI generation failed:", e)
        return None
