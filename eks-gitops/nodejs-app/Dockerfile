FROM node:23.11.0-slim
WORKDIR /app
COPY package*.json ./
RUN npm install --production && npm audit fix
COPY . .
EXPOSE 3000
CMD ["npm", "start"]