const elChatContainer = document.getElementById('chat');
elChatContainer.scrollIntoView({ behavior: "smooth", block: "end", inline: "nearest" });

window.appendChat = (owner, msg, koreanTime) => {
    const rootDiv = document.createElement('div');
    rootDiv.classList.add('bubble');
    rootDiv.classList.add(owner);
    
    const timeDiv = document.createElement('div');
    
    timeDiv.innerText = `[${koreanTime}]`;
    timeDiv.classList.add('timestamp');
    
    rootDiv.appendChild(timeDiv);

    const messageDiv = document.createElement('div');
    messageDiv.innerText =  msg;
    rootDiv.appendChild(messageDiv);

    elChatContainer.append(rootDiv);
    elChatContainer.scrollTop = elChatContainer.scrollHeight;
}