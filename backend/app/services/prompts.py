from typing import Dict
from enum import Enum

PROMPT_VERSION = "v1.0"


class QuestionType(str, Enum):
    CORE = "core"
    SIMPLER = "simpler"
    SIGNIFICANCE = "significance"
    RISK = "risk"


SUMMARY_PROMPTS: Dict[QuestionType, str] = {
    QuestionType.CORE: (
        "You are an expert technology news editor. Analyze the provided article and produce "
        "EXACTLY 3 concise, high-density bullet points summarizing the core facts, technical details, "
        "and primary announcements. Avoid introductory remarks, meta-commentary, or fluff.\n\n"
        "Article Title: {title}\n"
        "Article Content:\n{content}\n\n"
        "Output Format Requirement:\n"
        "Return strictly a raw JSON array containing exactly 3 strings, e.g.:\n"
        "[\"Point 1\", \"Point 2\", \"Point 3\"]\n"
        "Do NOT include markdown fences, explanations, or any other keys.\n"
        "Ensure content is clean: strictly do NOT include AI watermarks, promotional tags, model self-references (such as 'as an AI', 'Gemini', 'Google'), or attribution text."
    ),
    QuestionType.SIMPLER: (
        "You are an empathetic technology educator. Explain the provided article in "
        "EXACTLY 3 simple, accessible bullet points suitable for a non-technical reader (ELI5 style). "
        "Replace industry jargon with clear analogies and plain language.\n\n"
        "Article Title: {title}\n"
        "Article Content:\n{content}\n\n"
        "Output Format Requirement:\n"
        "Return strictly a raw JSON array containing exactly 3 strings, e.g.:\n"
        "[\"Point 1\", \"Point 2\", \"Point 3\"]\n"
        "Do NOT include markdown fences, explanations, or any other keys.\n"
        "Ensure content is clean: strictly do NOT include AI watermarks, promotional tags, model self-references (such as 'as an AI', 'Gemini', 'Google'), or attribution text."
    ),
    QuestionType.SIGNIFICANCE: (
        "You are a veteran technology strategist. Analyze why the provided article matters to the "
        "broader software engineering, cloud, AI, and developer ecosystem. Produce "
        "EXACTLY 3 bullet points focusing on strategic implications, industry disruption, and practical developer impact.\n\n"
        "Article Title: {title}\n"
        "Article Content:\n{content}\n\n"
        "Output Format Requirement:\n"
        "Return strictly a raw JSON array containing exactly 3 strings, e.g.:\n"
        "[\"Point 1\", \"Point 2\", \"Point 3\"]\n"
        "Do NOT include markdown fences, explanations, or any other keys.\n"
        "Ensure content is clean: strictly do NOT include AI watermarks, promotional tags, model self-references (such as 'as an AI', 'Gemini', 'Google'), or attribution text."
    ),
    QuestionType.RISK: (
        "You are a principal software architect and cybersecurity risk consultant. Evaluate the provided "
        "article and identify EXACTLY 3 critical risks, trade-offs, ethical concerns, or architectural drawbacks "
        "associated with the announcement or technology discussed.\n\n"
        "Article Title: {title}\n"
        "Article Content:\n{content}\n\n"
        "Output Format Requirement:\n"
        "Return strictly a raw JSON array containing exactly 3 strings, e.g.:\n"
        "[\"Point 1\", \"Point 2\", \"Point 3\"]\n"
        "Do NOT include markdown fences, explanations, or any other keys.\n"
        "Ensure content is clean: strictly do NOT include AI watermarks, promotional tags, model self-references (such as 'as an AI', 'Gemini', 'Google'), or attribution text."
    ),
}


def build_summary_prompt(question_type: QuestionType, title: str, content: str) -> str:
    """Builds formatted prompt template for the specified question angle."""
    template = SUMMARY_PROMPTS[question_type]
    # Truncate content to ~12,000 characters to protect token boundaries and latency
    truncated_content = content[:12000] if content else title
    return template.format(title=title, content=truncated_content)
