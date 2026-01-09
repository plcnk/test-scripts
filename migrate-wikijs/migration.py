#!/usr/bin/env python3
import requests
import json

WIKIJS_URL = "https://your-wikijs"
WIKIJS_TOKEN = "your-wikijs-token"
BOOKSTACK_URL = "https://your-bookstack"
BOOKSTACK_TOKEN = "your-bookstack-token"

# Export from Wiki.js
def export_wikijs_pages():
    query = """
    {
      pages {
        list {
          id
          path
          title
          content
          contentType
        }
      }
    }
    """
    response = requests.post(
        f"{WIKIJS_URL}/graphql",
        headers={"Authorization": f"Bearer {WIKIJS_TOKEN}"},
        json={"query": query}
    )
    return response.json()["data"]["pages"]["list"]

# Import to BookStack
def create_bookstack_page(book_id, title, content):
    response = requests.post(
        f"{BOOKSTACK_URL}/api/pages",
        headers={
            "Authorization": f"Token {BOOKSTACK_TOKEN}",
            "Content-Type": "application/json"
        },
        json={
            "book_id": book_id,
            "name": title,
            "markdown": content
        }
    )
    return response.json()

# Main migration
pages = export_wikijs_pages()
book_id = 1  # Your target BookStack book

for page in pages:
    print(f"Migrating: {page['title']}")
    create_bookstack_page(book_id, page["title"], page["content"])
