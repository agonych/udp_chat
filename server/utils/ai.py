"""
This module implements the AI prompt and response generation functions for the
chat application.

OpenAI and Ollama are supported.

Author: Andrej Kudriavcev
Last Updated: 15/05/2025
"""

from openai import OpenAI, AzureOpenAI
import ollama
import os

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
                f"You are '{user}' in a group chat. You are an intelligent, thoughtful person who: "
                f"- Reads the conversation context carefully and responds appropriately\n"
                f"- Uses natural, conversational language that fits the group dynamic\n"
                f"- Shows personality and engagement with the topic\n"
                f"- Asks relevant questions or adds valuable insights when appropriate\n"
                f"- Maintains a friendly, casual tone but can be serious when needed\n"
                f"- Responds concisely but meaningfully (1-2 sentences typically)\n"
                f"- Never mentions that you're an AI or reference your role\n"
                f"- Adapts your communication style to match the conversation flow\n"
                f"- Shows genuine interest in what others are saying\n"
                f"- Can be humorous, supportive, or analytical as the situation calls for"
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
                f"Based on the conversation above, what would {user} naturally say next? "
                f"Consider the context, tone, and flow of the discussion. "
                f"Respond as {user} would - naturally, engagingly, and appropriately. "
                f"Keep it conversational and authentic to the group dynamic."
            )
        })
    return prompt

def gtp_get_ai_response(messages, user, content, model="gpt-4o-mini"):
    """
    Get a chat response from OpenAI's GPT-4o-mini model.
    :param messages: List of messages in the chat.
    :param user: Name of the user to reply as.
    :param content: Content to improve (optional).
    :param model: The OpenAI model to use (default is "gpt-4o-mini").
    :return: AI generated response.
    """
    prompt = build_chat_prompt(messages, user, content)
    try:
        # Prefer Azure OpenAI when endpoint is configured; fallback to OpenAI
        azure_endpoint = os.getenv("AZURE_OPENAI_ENDPOINT")
        azure_deployment = os.getenv("AZURE_OPENAI_DEPLOYMENT")
        api_key = os.getenv("OPENAI_API_KEY")

        if azure_endpoint and azure_deployment:
            client = AzureOpenAI(
                azure_endpoint=azure_endpoint,
                api_key=api_key,
                api_version="2024-05-01-preview",
            )
            model_name = azure_deployment  # deployment name, not model id
        else:
            client = OpenAI(api_key=api_key)
            model_name = model

        response = client.chat.completions.create(
            model=model_name, 
            messages=prompt,
            temperature=0.8,  # More creative and natural responses
            max_tokens=150,   # Reasonable length for chat messages
            top_p=0.9,        # Good balance of creativity and coherence
            frequency_penalty=0.1,  # Slight penalty to avoid repetition
            presence_penalty=0.1    # Slight penalty to encourage new topics
        )
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
