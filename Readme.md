Sync across all devices
## Project Structure
- Files hosted on Google Drive
- On local network, GPU computer, clone https://github.com/jakkritz/jupyter-lab-server and start nvidia runtime docker container.
- Or use virtualenv (in this case 'fastai' environment), start jupyter lab server
- On other local computers, forward ssh intepreter i.e., ```ssh -N -L localhost:8888:localhost:8888 jakkrit@192.168.1.4```
