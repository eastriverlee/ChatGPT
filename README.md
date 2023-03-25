# ChatGPT

## OVERVIEW
A clean, tiny, flexible ChatGPT asynchronous library that can be tailored to your need.
## USAGE
Choose one method:
* Add `https://github.com/eastriverlee/ChatGPT.git` using SPM using Xcode.  
* Open `Package.swift` and add `.package(url: "https://github.com/eastriverlee/ChatGPT.git", branch: "master")` in dependencies.  
* Copy the only source file to your project.

Base url, path, custom headers can be configured so that you can send request to not only OpenAI, but to your proxy server as well.
```swift
import ChatGPT

var openAIChatGPT = ChatGPT()
let proxiedChatGPT = ChatGPT(baseURL: "https://your.proxy.server.com", path: "v1/chatGPT")
var userAPIKey: String = "USER API KEY" { didSet { openAIChatGPT.apiKey = userAPIKey } }
var chatGPT: ChatGPT { openAIChatGPT.apiKey == nil ? proxiedChatGPT : openAIChatGPT }
```

### BASIC
There are four types of result you can get:
1. `String`
1. `Result`
1. `StringStream`
1. `ResultStream`  

Using `AsyncThrowingStream`'s subtype `StringStream`, and `ResultStream`, you can (and probably should) get stream response without waiting for the server to come up with the whole response(which is not fast enough for users to feel comfortable waiting).

```swift
let systemPrompt = Message(role: .system, content: "You are ChatGPT, when user says something, you respond back as instructed.")

func printStringResponse(from whatYouSaid: String) async throws {
    print("You:", whatYouSaid)
    let answer = try await chatGPT.getStringResponse(from: [systemPrompt, .init(content: whatYouSaid)])
    print("ChatGPT:", answer)
}

func printResponse(from whatYouSaid: String) async throws {
    print("You:", whatYouSaid)
    let answer = try await chatGPT.getResponse(from: [systemPrompt, .init(content: whatYouSaid)])
    print("ChatGPT:", answer.choices[0].message.content)
    print("...used tokens:", answer.usage.totalTokens)
}

func printStreamResponse(from whatYouSaid: String) async throws {
    print("You:", whatYouSaid)
    let answer = try await chatGPT.getStreamResponse(from: [systemPrompt, .init(content: whatYouSaid)])
    print("ChatGPT:", terminator: " ")
    for try await answerDelta in answer {
        if let content = answerDelta.choices[0].delta.content {
            print(content, terminator: "")
            fflush(stdout)
        }
    }
}
```

### ADVANCED
You can set model or its hyper parameters using `Option` struct.
```swift
func printStringStreamResponse(from whatYouSaid: String, using model: Model) async throws {
    print("You:", whatYouSaid)
    let answer = try await chatGPT.getStringStreamResponse(from: [systemPrompt, .init(content: whatYouSaid)], with: Option(model: model))
    print("ChatGPT:", terminator: " ")
    for try await answerDelta in answer {
        print(answerDelta, terminator: "")
        fflush(stdout)
    }
}
```
---

## TEST
```swift
try await printStreamResponse(from: "Give me meaning of life in less than a hundred letters.", using: .gpt_4)
```
```
You: Give me meaning of life in less than a hundred letters.
ChatGPT: Life's meaning: seeking purpose, growth, love, and happiness while positively impacting others.
```

If my understanding is correct, OpenAI API does not provide information on how many tokens are used for streaming result.
If you need such functionality, get help from another swift library [GPT3-Tokenizer]("https://github.com/aespinilla/GPT3-Tokenizer")
