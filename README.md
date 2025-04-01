# Intercom + Slack + Notion Integration

## Overview

This integration connects **Intercom**, **Slack**, and **Notion** to streamline customer support ticket management. It allows teams to seamlessly create and manage tickets in Notion directly from Intercom, while also ensuring related Slack communication is automatically synchronized.

## Features

### 1. **Create Notion Ticket from Intercom**

- Users can select "Create Notion Ticket" from the three-dot menu on an Intercom message.
- The integration retrieves all existing ticket titles from Notion.
- An AI/LLM determines whether an existing ticket should be used or if a new ticket should be created.

### 2. **Avoiding Duplicate Tickets**

- If AI finds an existing relevant ticket, the Intercom conversation is linked to that ticket.
- If AI determines a new ticket is needed:
  - A new Notion ticket is created with:
    - **ID**: Generated with the prefix `JMP` (e.g., `JMP-123`)
    - **Intercom Conversations**: List of conversation URLs
    - **Title**: AI-generated ticket title
    - **Description**: AI-generated summary of the issue
    - **Slack Channel**: A link to the associated Slack channel

### 3. **Slack Channel Creation & Management**

- A Slack channel is created in the format `{Notion ticket ID}-{AI generated title slug}` (e.g., `#JMP-123-customer-exchange-wont-sync`).
- The Intercom API retrieves all participating admin users.
- The Slack API fetches all Slack users.
- The integration uses `String.jaro_distance` to match Intercom users to Slack users and automatically adds them to the Slack channel.
- The Slack channel topic is set to the Notion ticket URL.
- The Notion ticket is updated with the Slack channel link.

### 4. **Updating Existing Tickets**

- If AI selects an existing ticket:
  - The Intercom conversation is added to that ticket.
  - The Intercom admin users are matched to Slack users and added to the corresponding Slack channel.

### 5. **Closing Tickets**

- When a Notion ticket is marked as "Done":
  - A message is posted to the Slack channel.
  - All linked Intercom conversations receive a notification that the issue is resolved.

---

## Setup & Installation

### **Environment Variables**

Ensure the following environment variables are set:

```env
INTERCOM_API_KEY=<your-intercom-api-key>
NOTION_API_KEY=<your-notion-api-key>
NOTION_DATABASE_ID=<your-notion-database-id>
SLACK_API_TOKEN=<your-slack-api-token>
GOOGLE_GEMINI_API_KEY=<your-google-gemini-api-key>
INTERCOM_ADMIN_ID=<your-intercom-admin-id>
INTERCOM_APP_ID=<your-intercom-app-id>
```

### **Installation**

1. Clone the repository:
   ```sh
   git clone <repo_url>
   cd intercom-slack-notion-integration
   ```
2. Install dependencies:
   ```sh
   mix setup
   ```
3. Set up environment variables (see `.env.example` for reference).
4. Start the Phoenix server:
   ```sh
   mix phx.server
   ```
   Or start it inside IEx:
   ```sh
   iex -S mix phx.server
   ```
5. Visit `http://localhost:4000` in your browser.

### **Intercom Setup**

- Register an Intercom app in [Intercom Developer Hub](https://developers.intercom.com/).
- Add a **Custom Action** in Intercom for "Create Notion Ticket."
- Configure the action to call this service's API endpoint.

### **Notion Setup**

- Create a database in Notion with required fields (`ID`, `Intercom Conversations`, `Title`, `Description`, `Slack Channel`).
- Share the database with the Notion integration bot.

### **Slack Setup**

- Create a Slack App in [Slack API Dashboard](https://api.slack.com/apps).
- Enable the required scopes (`channels:manage`, `channels:write`, `users:read`, `chat:write`).
- Install the app in your Slack workspace.

---

## API Endpoints

### `POST /create-ticket`

Triggered when "Create Notion Ticket" is selected in Intercom.

#### Request Body:

```json
{
  "intercom_conversation_id": "1234567890",
  "message": "Customer is experiencing an issue with syncing."
}
```

#### Response:

```json
{
  "status": "success",
  "notion_ticket_id": "JMP-123",
  "slack_channel": "#JMP-123-customer-exchange-wont-sync"
}
```

### `POST /ticket-done`

Triggered when a Notion ticket is marked as "Done."

#### Request Body:

```json
{
  "notion_ticket_id": "JMP-123"
}
```

#### Response:

```json
{
  "status": "success",
  "message": "Ticket closed in Slack and Intercom."
}
```

---

## Technologies Used

- **Intercom API** (for retrieving and updating conversations)
- **Notion API** (for ticket management)
- **Slack API** (for channel creation and user management)
- **Google Gemini AI** (for AI-driven ticket categorization and title generation)
- **String.jaro_distance** (for fuzzy name matching between Intercom and Slack users)

---

## Contributing

Feel free to open issues and submit pull requests to improve the integration.

---

## License

This project is licensed under the MIT License.

