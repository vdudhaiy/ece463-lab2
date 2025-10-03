/* The code is subject to Purdue University copyright policies.
 * Do not share, distribute, or post online.
 */

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <signal.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/select.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <netdb.h>
#include <arpa/inet.h>

#define LISTEN_QUEUE 50 /* Max outstanding connection requests; listen() param */
#define DBADDR "127.0.0.1"
#define FILE_CHUNK_SIZE 4096
#define TOP_DIR "Webpage"

// Function declarations
int send400badrequest(int client_fd, char* client_ip, char* log_first_line);
int validateURL(char* url, char* client_ip, char* log_first_line);
void log_request(char* client_ip, char* first_line, char* status_code);
int sendFile(int client_fd, char* filepath, char* client_ip, char* log_first_line);

// Function definitions
int send400badrequest(int client_fd, char* client_ip, char* log_first_line){
	// Respond with HTTP/1.0 400 Bad Request
	char response[2048] =  "HTTP/1.0 400 Bad Request\r\n[blank line]\r\n<html><body><h1>400 Bad Request</h1></body></html>";
	
	// Ensure send has worked
	if (send(client_fd, response, strlen(response), 0) < 0) {
		perror("send");
		return -1;
	}
	close(client_fd);
	log_request(client_ip, log_first_line, "400 Bad Request");
	return 1;
}

int validateURL(char* url, char* client_ip, char* log_first_line){
	// Check if URL starts with '/'
	if (url[0] != '/'){
		return 0; // Invalid URL
	}

	// Check for '/../' in the URL
	if (strstr(url, "/../") != NULL){
		return 0; // Invalid URL
	}

	// Check if URL ends with '/..'
	int len = strlen(url);
	if (len >= 3 && strcmp(&url[len - 3], "/..") == 0){
		return 0; // Invalid URL
	}

	return 1; // Valid URL
}

void log_request(char* client_ip,  char* first_line, char* status_code){
	// Log the request to the console
	// Example log format: 128.59.22.109 "GET /index.html HTTP/1.1" 200 OK
	printf("%s \"%s\" %s\n", client_ip, first_line, status_code);
}

int sendFile(int client_fd, char* filepath, char* client_ip, char* log_first_line){
	FILE *file = fopen(filepath, "r");
	// printf("log_first_line: %s\n", log_first_line);
	if (file == NULL) {
		// Send HTTP/1.0 404 Not Found
		char header[2048];
		snprintf(header, sizeof(header), "HTTP/1.0 404 Not Found\r\n\r\n");
		if (send(client_fd, header, strlen(header), 0) < 0) {
			fclose(file);
			perror("send");
			return -1;
		}
		log_request(client_ip, log_first_line, "404 Not Found");
		return 0;
	}

	// Send HTTP/1.0 200 OK header
	char header[2048];
	snprintf(header, sizeof(header), "HTTP/1.0 200 OK\r\n\r\n");
	if (send(client_fd, header, strlen(header), 0) < 0) {
		fclose(file);
		perror("send");
		return -1;
	}

	// Send file content
	char buffer[FILE_CHUNK_SIZE];
	size_t bytesRead;
	while ((bytesRead = fread(buffer, 1, sizeof(buffer), file)) > 0) {
		if (send(client_fd, buffer, bytesRead, 0) < 0) {
			fclose(file);
			perror("send");
			return -2;
		}
	}
	fclose(file);
	log_request(client_ip, log_first_line, "200 OK");
	return 1;
}

// Main function
int main(int argc, char *argv[])
{	
	setvbuf(stdout, NULL, _IONBF, 0); // disable buffering for stdout

	printf("Starting HTTP server...\n");
    // Ensure valid command format
	printf("Validating command line arguments...\n");
    if (argc != 3) {
        fprintf(stderr, "usage: ./http_server [server port] [DB port]\n");
        exit(1);
    }

    // Variables
    int sockfd, new_fd; // listening socket and new connection socket
	struct sockaddr_in my_addr; /* to store server's address info */
	struct sockaddr_in their_addr; /* to store client's address info */
	int sin_size;
	char client_ip[INET_ADDRSTRLEN]; // buffer to store client IP address string

    // Create socket
	printf("Creating socket...\n");
    if ((sockfd = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
		perror("socket");
		exit(1);
	}

	// Configure server address struct
    my_addr.sin_family = AF_INET; // IPv4
	my_addr.sin_port = htons(atoi(argv[1])); // Server port number
	my_addr.sin_addr.s_addr = INADDR_ANY; /* bind to all local interfaces */
	bzero(&(my_addr.sin_zero), 8); // Zero out padding bytes

	// Bind socket to the specified port and address
	printf("Binding socket to port %s...\n", argv[1]);
	if (bind(sockfd, (struct sockaddr *) &my_addr, sizeof(struct sockaddr)) < 0) {
		perror("bind");
		exit(1);
	}

	// Listen for incoming connections (queue size = LISTEN_QUEUE)
	printf("Listening for incoming connections...\n");
	if (listen(sockfd, LISTEN_QUEUE) < 0) {
		perror("listen");
		exit(1);
	}

	// Main server loop: continuously accept client connections (must handle 1 request at a time)
	printf("Server is ready to accept connections.\n");
	while(1) {
		sin_size = sizeof(struct sockaddr_in);

		// Accept a new connection
		printf("Waiting to accept a new connection...\n");
		if ((new_fd = accept(sockfd, (struct sockaddr *) &their_addr, &sin_size)) < 0) {
			perror("accept");
			exit(1); // exit if accept fails
			// continue; // Should we continue if accept fails?
		}
		printf("Accepted a new connection.\n");

		// Convert client IP to human-readable form
		inet_ntop(AF_INET, &(their_addr.sin_addr), client_ip, INET_ADDRSTRLEN);
		// printf("server: got connection from %s\n", client_ip);

		char request[2048]; // Buffer for client request
		
		// Receive request from client
		int bytes_received = recv(new_fd, request, sizeof(request) - 1, 0);
		if (bytes_received >= 0) {
			request[bytes_received] = '\0'; // Null-terminate the received string
			// printf("Received request:\n%s\n", request);
		}
		else{
			perror("recv");
			close(new_fd);
			exit(1); // exit if recv fails
		}
		
		printf("Processing request...\n");

		// Parse headers to find the end of headers, if not found, then it means the request is too large, reject and return 400 Bad Request
        char *header_end = strstr(request, "\r\n\r\n");

		// Extract request URL from the first line of the request
		char* first_line = strtok(request, "\r\n"); // first line of the request
		
		// create a copy of first_line to log later
		char log_first_line[2048];
		if (first_line != NULL) {
			snprintf(log_first_line, sizeof(log_first_line), "%s", first_line);
		} else {
			log_first_line[0] = '\0';
		}

		if (header_end == NULL){
			printf("Request headers too large or malformed, sending 400 Bad Request.\n");
			if (send400badrequest(new_fd, client_ip, log_first_line) < 0){
				close(new_fd);
				exit(1); // exit if send400badrequest fails?
			}
			continue; // continue listening for next request
		}
		
		// Ensure it is a GET request
		if (first_line != NULL && strncmp(first_line, "GET ", 4) == 0) {
			printf("Request is a GET request.\n");
			printf("First line of request: %s\n", first_line);
			// Tokenize the first line to extract the method, URL, and HTTP version
			char* method = strtok(first_line, " "); // "GET"
			char* url = strtok(NULL, " "); // "/path"
			char* http_version = strtok(NULL, " "); // "HTTP/1.0" or "HTTP/1.1"

			// display method, url, http_version using
			printf("Method: %s, URL: %s, HTTP Version: %s\n", method, url, http_version);

			// printf("log_first_line in main: %s\n", log_first_line);

			// Validate URL
			if (validateURL(url, client_ip, log_first_line) == 1){
				// Serve the requested file/directory/URL
				struct stat buffer;
				int status;

				printf("Request URL is valid: %s\n", url);

				char filepath[2048]; // Separate buffer for actual file path to serve

				// If the URL is just "/", serve "/index.html"
				if (strcmp(url, "/") == 0){
					printf("Request URL is root '/', serving '/index.html'\n");
					snprintf(filepath, sizeof(filepath), "%s/index.html", TOP_DIR);
				}
				// If the request URL is a directory (check using stat)
				else if (stat(url, &buffer) == 0 && S_ISDIR(buffer.st_mode)){
					printf("Request URL is a directory, appending '/index.html'\n");
					snprintf(filepath, sizeof(filepath), "%s%s/index.html", TOP_DIR, url);
				}
				// Otherwise, treat as a file
				else{
					printf("Request URL is a file, serving the file.\n");
					snprintf(filepath, sizeof(filepath), "%s%s", TOP_DIR, url);
				}

				printf("Attempting to send file: %s\n", filepath);
				if (sendFile(new_fd, filepath, client_ip, log_first_line) < 0){
					close(new_fd);
					exit(1); // exit if sendFile fails
				}
			}
			else{
					if (send400badrequest(new_fd, client_ip, log_first_line) < 0){
						close(new_fd);
						exit(1); // exit if send400badrequest fails
					}
					continue; // continue listening for next request
				}
		}
		else{
			// Respond with HTTP/1.0 501 Not Implemented
			char response[2048] = "HTTP/1.0 501 Not Implemented\r\n\r\n<html><body><h1>501 Not Implemented</h1></body></html>";
			
			// Ensure send has worked
			if (send(new_fd, response, strlen(response), 0) < 0) {
				perror("send");
				exit(1);
			}
			log_request(client_ip, log_first_line, "501 Not Implemented");
		}		
		// close connection with current client
		close(new_fd);
	}

    return 0;
}
