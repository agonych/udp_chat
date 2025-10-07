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
                f"You are '{user}' in a group chat. You are knowledgeable, helpful, and engaging. Your responses should: "
                f"- Provide substantive, useful information when asked questions\n"
                f"- Be specific and detailed rather than generic\n"
                f"- Show genuine expertise and willingness to help\n"
                f"- Use examples and practical details when explaining concepts\n"
                f"- Ask follow-up questions that show you're thinking deeper about the topic\n"
                f"- Be conversational but informative - like talking to a knowledgeable friend\n"
                f"- Avoid repetitive phrases or generic responses\n"
                f"- Match the user's level of interest and technical depth\n"
                f"- Be encouraging and supportive while being genuinely helpful\n"
                f"- Don't just acknowledge questions - actually answer them with useful content"
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
                f"Be helpful, informative, and engaging. If someone asked a question, provide a detailed, "
                f"useful answer. If they're learning something, give them practical information and examples. "
                f"Show your knowledge and be genuinely helpful rather than just acknowledging their question. "
                f"Respond as {user} would - like a knowledgeable friend who wants to help."
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
            temperature=0.9,  # More creative and varied responses
            max_tokens=300,   # Allow longer, more detailed responses
            top_p=0.95,       # More creative word choices
            frequency_penalty=0.3,  # Stronger penalty to avoid repetition
            presence_penalty=0.2    # Encourage new topics and details
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
