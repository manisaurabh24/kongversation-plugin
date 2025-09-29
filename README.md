# Stateless LLMs with Smart Contextual Memory using Kong Gateway  
  
## Overview  
  
Large Language Models (LLMs) are stateless by design — they don’t remember past interactions unless you send the full conversation every time. This creates overhead for developers and clients.  
  
This project demonstrates how to use Kong Gateway with kongversation-plugin to provide a conversation memory layer.  
• Stores chat history per consumer-key or short lived oauth token in Kong, not the LLM.  
• Automatically appends message history before sending to the LLM.  
• Keeps the LLM backend stateless and scalable.  
• Provides a seamless “chat-like” experience for consuming applications.  
  
  <p align="center" width="100%">
    <img src="assets/Kongversation.gif">
</p>
  
## Industry Use Cases   
This pattern is useful across industries where chat-based or context-aware interactions are needed:  
• Customer Support 🛠️ – Context-aware bots that remember past questions.  
• Banking & Finance 💳 – Secure, per-customer conversational AI (history tied to consumer-key or token).  
• Healthcare 🏥 – Patient chatbots that recall recent medical interactions while keeping backend stateless.  
• E-commerce 🛒 – Personalized shopping assistants that remember preferences.  
• Enterprise Apps 🏢 – AI copilots that assist employees across multiple requests without duplicating input.  
  
## Installing the plugin
There are two things necessary to make a custom plugin work in Kong:
1. Install it locally (based on the .rockspec in the current directory): 
```
 sudo luarocks make
```
2. Pack the installed rock: 
```
luarocks pack YOUR-PLUGIN-NAME PLUGIN-VERSION
```
3. Load the plugin files.
The easiest way to install the plugin is using `luarocks`.
```
luarocks install https://github.com/manisaurabh24/kongversation-plugin/kongversation-plugin-1.0-1.all.rock
```

You can substitute `0.1.0-1` in the command above with any other version you want to install.


5. Specify that you want to use the plugin by modifying the plugins property in the Kong configuration.

Add the custom plugin’s name to the list of plugins in your Kong configuration:

```conf
plugins = bundled, kongversation-plugin
```

If you are using the Kong helm chart, create a configMap with the plugin files and add it to your `values.yaml` file:

```yaml
# values.yaml
plugins:
  configMaps:
  - name: kongversation-plugin
    pluginName: kongversation-plugin
```
  
## Configuring Kong Gateway - Without KongVersation Plugin 

1\. Enable Required Plugins  
  
This project uses:  
• key-auth → authenticate clients using consumer-key or oauth token in header.  
• ai-contextualizer → manage and cache conversation history per consumer-key or oauth token in header.  
• ai-proxy → forward the request to the LLM (Azure , OpenAI, Anthropic, or other providers).  
<p align="center" width="100%">
    <img src="assets/Kongversation.gif">
</p>
  
  
2\. Example Declarative Config (kong.yaml)  
change the config based on your llm and target server. Eg:
```
_format_version: "3.0"
_info:
  select_tags:
  - kongversation
_konnect:
  control_plane_name: tcsai
services:
- name: kongversation-service
  url: https://httpbin.konghq.com
  routes:
  - name: kongversation-route
    paths:
    - /kongversation
    plugins:
    - name: ai-proxy
      instance_name: "ai-proxy-kongversation"
      enabled: true
      config:
        balancer:
          algorithm: round-robin
          connect_timeout: 60000
          failover_criteria:
            - error
            - timeout
          hash_on_header: X-Kong-LLM-Request-ID
          latency_strategy: tpot
          read_timeout: 60000
          retries: 5
          slots: 10000
          tokens_count_strategy: total-tokens
          write_timeout: 60000
        embeddings: null
        genai_category: text/generation
        llm_format: openai
        max_request_body_size: 8192
        model_name_header: true
        response_streaming: allow
        targets:
          - auth:
              allow_override: false
              aws_secret_access_key: null
              azure_client_id: null
              azure_client_secret: null
              azure_tenant_id: null
              azure_use_managed_identity: false
              header_name: api-key
              header_value: '{vault://azure-openai/apikey}'
              param_location: null
              param_name: null
              param_value: null
            description: null
            logging:
              log_payloads: false
              log_statistics: true
            model:
              name: null
              options:
                anthropic_version: null
                azure_api_version: <<replace>>
                azure_deployment_id: <<replace>>
                azure_instance: <<replace>>
              provider: azure
            route_type: llm/v1/chat
            weight: 100
        vectordb: null
      enabled: true
      id: 710bc3cc-cca7-472d-ab55-3b1fb1b1dd31
      name: ai-proxy-advanced
      protocols:
        - grpc
        - grpcs
        - http
        - https
    - name: ai-prompt-decorator
      instance_name: ai-prompt-decorator-kongversation
      enabled: true
      config:
        prompts:
          prepend:
          - role: system
            content: "You will always respond in the English (India) language."
    - name: key-auth
      instance_name: key-auth-kongversation
      enabled: true
   
consumers:
  - username: kongversation-app-a                              
    keyauth_credentials:
      - key: kongversation-app-a-123                      
  - username: kongversation-app-b                          
    keyauth_credentials:
      - key: kongversation-app-b-123               
 
  
  
```

  
▶️ Testing the Setup  - - Without KongVersation Plgin 
  
Request 1  
```
curl --location 'http://localhost:8000/kongversation' \
--header 'Content-Type: application/json' \
--header 'apikey: kongversation-app-a-123' \
--data '{
    "model": "gpt-4",
    "messages": [
      {"role": "user", "content": "Tell me about TCS?"}
    ]
  }'
```
👉 Sent to LLM:  
```
{ "messages": \["Tell me about TCS"\] }  
```
 
⸻  
  
Request 2  
```
curl --location 'http://localhost:8000/kongversation' \
--header 'Content-Type: application/json' \
--header 'apikey: kongversation-app-a-123' \
--data '{
    "model": "gpt-4",
    "messages": [
      {"role": "user", "content": "How many employees ?"}
    ]
  }' 
```
👉 Sent to LLM: 
```
{ "messages": \["Tell me about TCS", "How many employees?"\] }  
  
```
⸻  

Resetting History  
  
If you want to clear the conversation for a client (new chat), you can:  
• Set a lower ttl in ai-contextualizer, or  
• Extend the plugin logic to check for a custom header like X-Reset-Conversation: true and clear cached history.  
  
⸻  
  
🚀 Benefits  
• Keeps LLM stateless → scalable and provider-agnostic.  
• Adds smart memory at the API layer.  
• Provides per-client isolation using apikey.  
• Reduces developer effort → no need to manage conversation state in apps.  
  
⸻  
  
Would you like me to also add a diagram (sequence flow) in the README (using Mermaid or ASCII) to make the request flow crystal clear for hackathon judges?Got it ✅ — here’s a structured README.md draft for your repository that explains the idea, industry relevance, setup, and an example flow.  
  
⸻  
  
🧠 Stateless LLMs with Smart Contextual Memory using Kong Gateway  
  
📌 Overview  
  
Large Language Models (LLMs) are stateless by design — they don’t remember past interactions unless you send the full conversation every time. This creates overhead for developers and clients.  
  
This project demonstrates how to use Kong Gateway with AI Plugins to provide a conversation memory layer.  
• Stores chat history per client (apikey) in Kong, not the LLM.  
• Automatically appends past messages before sending to the LLM.  
• Keeps the LLM backend stateless and scalable.  
• Provides a seamless “chat-like” experience for clients.  
  
⸻  
  
🌍 Industry Use Cases  
  
This pattern is useful across industries where chat-based or context-aware interactions are needed:  
• Customer Support 🛠️ – Context-aware bots that remember past questions.  
• Banking & Finance 💳 – Secure, per-customer conversational AI (history tied to API keys).  
• Healthcare 🏥 – Patient chatbots that recall recent medical interactions while keeping backend stateless.  
• E-commerce 🛒 – Personalized shopping assistants that remember preferences.  
• Enterprise Apps 🏢 – AI copilots that assist employees across multiple requests without duplicating input.  
  
⸻  
  
⚙️ Configuring Kong Gateway  
  
1\. Enable Required Plugins  
  
This project uses:  
• key-auth → authenticate clients using apikey header.  
• ai-contextualizer → manage and cache conversation history per API key.  
• ai-proxy → forward the request to the LLM (OpenAI, Anthropic, or other providers).  
  
2\. Example Declarative Config (kong.yaml)  
```  
\_format\_version: "3.0"  
\_transform: true  
  
services:  
 - name: llm-service  
   url: [https://your-llm-backend.example.com/v1/chat](https://your-llm-backend.example.com/v1/chat "https://your-llm-backend.example.com/v1/chat")  
   routes:  
     - name: chat-route  
       paths: \[ /chat \]  
       methods: \[ POST \]  
       plugins:  
         - name: key-auth  
           config:  
             key\_names: \[apikey\]  
             hide\_credentials: true  
  
         - name: ai-contextualizer  
           config:  
             strategy: memory  
             ttl: 3600             # 1 hour history  
             key: apikey  
             input\_key: message  
             output\_key: messages  
  
         - name: ai-proxy  
           config:  
             route\_type: chat  
             model:  
               provider: openai     # change provider if needed  
               name: gpt-4o-mini  
             auth:  
               header\_name: Authorization  
               header\_value: "Bearer ${LLM\_API\_KEY}"  
  
```
⸻  
  
▶️ Testing the Setup  
  
Request 1  
```
curl -X POST [http://localhost:8000/chat](http://localhost:8000/chat "http://localhost:8000/chat") \\  
 -H "apikey: xyz123" \\  
 -H "Content-Type: application/json" \\  
 -d '{ "message": "Tell me something about" }'  
```
👉 Sent to LLM:  
```  
{ "messages": \["Tell me something about"\] }  
```
  
⸻  

Request 2  
  
``` 
curl -X POST [http://localhost:8000/chat](http://localhost:8000/chat "http://localhost:8000/chat") \\  
 -H "apikey: xyz123" \\  
 -H "Content-Type: application/json" \\  
 -d '{ "message": "How many employees?" }'  
```  
👉 Sent to LLM:  
```  
{ "messages": \["Tell me something about", "How many employees?"\] }  
```  
  
⸻  
  
Resetting History  
  
If you want to clear the conversation for a client (new chat), you can:  
• Set a lower ttl in ai-contextualizer, or  
• Extend the plugin logic to check for a custom header like X-Reset-Conversation: true and clear cached history.  
  
⸻  
  
🚀 Benefits  
• Keeps LLM stateless → scalable and provider-agnostic.  
• Adds smart memory at the API layer.  
• Provides per-client isolation using apikey.  
• Reduces developer effort → no need to manage conversation state in apps.  
  
⸻  
  
Would you like me to also add a diagram (sequence flow) in the README (using Mermaid or ASCII) to make the request flow crystal clear for hackathon judges?

```
PAT="update_pat_token_here"
deck gateway ping --konnect-control-plane-name <control_plane_name> --konnect-token $PAT
deck gateway sync --konnect-control-plane-name <control_plane_name> --konnect-token $PAT kong_without_custom_plugin.yaml
deck gateway sync --konnect-control-plane-name tcsai --konnect-token $PAT kong.yaml
```