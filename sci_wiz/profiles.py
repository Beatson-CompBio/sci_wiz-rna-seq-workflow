#!/usr/bin/env python
"""
Created on 2024-01-25 17:09:23
Module desc: Modules to consider different profiles from users' input.
@author: m.sikarwar
"""
from abc import ABCMeta, abstractmethod
import logging
import subprocess
import sys
import time
from jinja2 import Template
from getpass import getuser


log = logging.getLogger(__name__)


PUMP_SLURM_TEMPLATE = """#!/bin/bash --login
#
#SBATCH --job-name=nf-parent
#SBATCH --output=%x.%j.out
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=24:00:00
#SBATCH --mem=8G

date
hostname
PWD=$(pwd)
echo $PWD
module load nextflow
export NXF_WORK=$PWD/to_be_removed

nextflow run {{ workflow}} \\
    -c {{ config }} \\
    -profile hpc,{{ engineStr }}\\
    -params-file {{ inputJson }}\\
    -resume \\
    {% if entryPoint %} -entry {{ entryPoint }} {% endif %}
"""


class ErrorAtSlurmSubmission(Exception):
    pass


class ErrorInNextflowProc(Exception):
    pass


class IProfile(metaclass=ABCMeta):
    """
    command interface that each command will implement.
    """

    @staticmethod
    @abstractmethod
    def trigger_nf():
        """
        trigger the nextflow workflow.
        """
        pass


class vm(IProfile):
    """
    Vm profile; when running data pre processing in a virtual machine nextflow
    is triggered with different set of configurations and triggered directly
    from the users console.
    """

    @classmethod
    def trigger_nf(cls, **kwargs):
        """
        Trigger the nextflow workflow in a virtual machine and take care of
        the setup.
        """
        workflow = kwargs.get("workflow")
        config = kwargs.get("config")
        inputJson = kwargs.get("inputJson")
        entryPoint = kwargs.get("entryPoint", "")
        engineStr = kwargs.get("engineStr", "docker")
        log.info("Profile: vm")
        entryPointStr = " -entry {}".format(entryPoint) if entryPoint else ""
        command = """nextflow run {} -c {} -profile vm,{}
        -params-file {}{} -resume""".format(
            workflow,
            config,
            engineStr,
            inputJson,
            entryPointStr,
        )
        # print(command)
        with subprocess.Popen(
            command.split(), stdout=subprocess.PIPE, bufsize=1, universal_newlines=True
        ) as p:
            for line in p.stdout:
                sys.stdout.write(line)
                sys.stdout.flush()
            if p.wait() != 0:
                msg = """Existing; Nextflow process returned non zero exit status. Check '.nextflow.log' file"""
                raise ErrorInNextflowProc(msg)
        pass


class hpc(IProfile):
    """
    HPC profile; when running data pre processing in a HPC nextflow
    sets the required the scripts
    """

    @classmethod
    def wait_for_slurm_job(cls, jobId: str):
        """
        Method to wait for slurm job using the job id.
        Args:
            jobId (str): job id of the slurm job.
        """
        log.info(f"waiting for slurm job: {jobId} ")
        while True:
            status = subprocess.run(
                ["squeue", "-j", jobId], capture_output=True, text=True
            )
            squeueOutput = status.stdout.strip().split("\n")
            if len(squeueOutput) == 1:
                sacct = subprocess.run(
                    ["sacct", "-j", jobId], capture_output=True, text=True
                )
                sacctOutput = sacct.stdout.strip().split("\n")
                log.info(
                    f"""slurm job {jobId} finished with status:{
                        sacctOutput[2].split()[5]
                    } with exit code: {sacctOutput[2].split()[6]}"""
                )
                break
            else:
                user = getuser()
                queue = subprocess.run(
                    ["squeue", "-u", user], capture_output=True, text=True
                )
                jobOutput = queue.stdout.strip().split("\n")
                jobNames = []
                for job in jobOutput[1:]:
                    jobNames.append(job.split()[2])
                log.info(
                    f"""Currently running job(s): {
                    ' , '.join(set(jobNames))
                }"""
                )
                time.sleep(60)

    @classmethod
    def trigger_nf(cls, **kwargs):
        """
        Trigger the nextflow workflow in a HPC and take care of the setup.
        Args:
            kwargs (dict): keyword arguments
                profile (str): profile name
                workflow (str): workflow name
                config (str): configuration file
                inputJson (str): input json file.
        """
        workflow = kwargs.get("workflow")
        config = kwargs.get("config")
        inputJson = kwargs.get("inputJson")
        entryPoint = kwargs.get("entryPoint", "")
        engineStr = kwargs.get("engineStr", "singularity")
        log.info("Profile: hpc")
        slurmTemplate = Template(PUMP_SLURM_TEMPLATE)
        renderedSlurmScript = slurmTemplate.render(
            workflow=workflow, config=config, inputJson=inputJson, entryPoint=entryPoint, engineStr=engineStr
        )
        # print(renderedSlurmScript)
        slurmCommand = f"echo -e '{renderedSlurmScript}' | sbatch"
        submissionProc = subprocess.run(
            ["bash", "-c", slurmCommand], capture_output=True, text=True
        )
        if submissionProc.returncode != 0:
            msg = f"""Something went wrong with slurm submission with error: {
                submissionProc.stderr
            }"""
            raise ErrorAtSlurmSubmission(msg)
        else:
            jobId = submissionProc.stdout.split()[-1]
            cls.wait_for_slurm_job(jobId)
        pass
