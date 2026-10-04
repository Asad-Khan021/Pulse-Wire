import pytest
from unittest.mock import patch, AsyncMock
from app.services.feed_fetcher import (
    assign_category,
    assign_categories,
    fetch_tech_news_feed,
)


def test_categorize_machine_learning():
    title = "New PyTorch 2.5 Features Accelerate Neural Network Training"
    desc = "Deep learning researchers achieve 3x faster training with transformer optimizations."
    cats = assign_categories(title, desc)

    assert "Machine Learning" in cats
    assert "AI" in cats  # ML also routes to AI
    assert assign_category(title, desc) in ["Machine Learning", "AI"]


def test_categorize_ai():
    title = "Anthropic Unveils Claude 3.7 with Hybrid Reasoning"
    desc = "The new LLM combines instant generation with extended thinking for complex engineering tasks."
    cats = assign_categories(title, desc)

    assert "AI" in cats
    assert assign_category(title, desc) == "AI"


def test_categorize_cybersecurity():
    title = "Critical Zero-Day Vulnerability Discovered in OpenSSL"
    desc = "Security researchers warn of active exploit malware and ransomware attacks."
    cats = assign_categories(title, desc)

    assert "Cybersecurity" in cats
    assert assign_category(title, desc) == "Cybersecurity"


def test_categorize_cloud_and_hardware():
    title = "Nvidia Unveils Next-Gen B200 GPU Chip for AWS Data Centers"
    desc = "Cloud infrastructure meets custom silicon with liquid cooling."
    cats = assign_categories(title, desc)

    assert "Hardware" in cats
    assert "Cloud" in cats


def test_categorize_fallback_general_tech():
    title = "Smartphone Sales Plateau in Q3 Report"
    desc = "Global consumer device shipments maintain modest year-over-year stability."
    cats = assign_categories(title, desc)

    assert cats == ["General Tech"]
    assert assign_category(title, desc) == "General Tech"


@pytest.mark.asyncio
async def test_fetch_tech_news_feed_success():
    fake_newsapi_response = {
        "status": "ok",
        "totalResults": 3,
        "articles": [
            {
                "title": "OpenAI Announces GPT-5 Developer Beta",
                "description": "The artificial intelligence lab introduces agentic features.",
                "source": {"id": "wired", "name": "Wired"},
                "url": "https://wired.com/openai-gpt5",
                "urlToImage": "https://wired.com/img.jpg",
                "publishedAt": "2026-09-24T18:00:00Z",
            },
            {
                "title": "Major Ransomware Breach Hits Healthcare Provider",
                "description": "Hackers exploit unpatched vulnerability.",
                "source": {"id": "techcrunch", "name": "TechCrunch"},
                "url": "https://techcrunch.com/breach",
                "urlToImage": None,
                "publishedAt": "2026-09-24T17:30:00Z",
            },
            {
                "title": "[Removed]",
                "description": "[Removed]",
                "source": {"name": "[Removed]"},
                "url": "https://removed.com",
            },
        ],
    }

    from unittest.mock import MagicMock
    mock_client = AsyncMock()
    mock_resp = MagicMock()
    mock_resp.json.return_value = fake_newsapi_response
    mock_client.get.return_value = mock_resp
    mock_client.__aenter__.return_value = mock_client
    mock_client.__aexit__.return_value = None

    with patch("httpx.AsyncClient", return_value=mock_client):
        res = await fetch_tech_news_feed(api_key="test-key")

    assert res["status"] == "success"
    # [Removed] article must be filtered out
    assert res["totalResults"] == 2
    assert len(res["articles"]) == 2

    # Check AI routing
    ai_article = res["articles"][0]
    assert ai_article["category"] == "AI"
    assert "AI" in ai_article["categories"]
    assert ai_article["source"] == "Wired"

    # Check Cybersecurity routing
    cyber_article = res["articles"][1]
    assert cyber_article["category"] == "Cybersecurity"
    assert "Cybersecurity" in cyber_article["categories"]
