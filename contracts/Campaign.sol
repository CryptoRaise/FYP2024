// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract CampaignFactory {
    address[] public deployedCampaigns;

    struct CampaignDetails {
        address campaignAddress;
        string title;
        string desc;
        string imgURI;
        uint targetAmt;
    }

    event campaignCreated(
        string indexed category,
        string indexed country,
        uint indexed deadline,
        CampaignDetails details
    );

    function createCampaign(
        string memory title,
        string memory desc,
        uint targetAmt,
        string memory imgURI,
        string memory category,
        string memory country,
        uint deadline,
        uint threshold,
        uint n1,
        uint n2
    ) public {
        uint _deadline = (block.timestamp + (deadline * 24 * 60 * 60));
        Campaign new_camp = new Campaign(
            title,
            desc,
            targetAmt,
            imgURI,
            category,
            country,
            _deadline,
            msg.sender,
            threshold,
            n1,
            n2
        );

        address campaignAddress = address(new_camp);
        deployedCampaigns.push(address(new_camp));

        CampaignDetails memory details = CampaignDetails({
            campaignAddress: campaignAddress,
            title: title,
            desc: desc,
            imgURI: imgURI,
            targetAmt: targetAmt
        });
        emit campaignCreated(category, country, _deadline, details);
    }
}

contract Campaign {
    address payable public owner;
    string public title;
    string public desc;
    uint public targetAmt;
    string public imgURI;
    string public category;
    uint public amtraised;
    string public country;
    uint public deadline;
    uint public threshold;
    uint ind;
    uint[3] installments;
    uint public contributorsCount;
    uint public disbursed; // stores the total disbursed amount till now
    bool public isCampaignOpen;
    bool public targetAchieved;
    uint[2][2] public votes; // 2 times vote need to be casted, so a size 2 array, each with 2 options :- yes(0), no(1)
    uint votingInd; // maintains the no of time the vote is going to be casted
    bool public auditReport;
    uint public auditReportCount;
    mapping(address => address[]) public contributors;
    mapping(address => uint) contribution;
    mapping(address => uint) balances;
    mapping(address => bool)[2] hasVoted; // map to maintain whether a person(address) has casted vote or not(bool) in
    // nth(n=2, 0<=i<n) time(so array of size 2)
    uint n1;
    uint n2;

    event ContributionAdded(
        address indexed contributor,
        uint amount,
        uint timestamp
    );
    event AuditReportSubmitted(
        address indexed owner,
        string message,
        uint timestamp
    );
    event VoteRegistered(
        address indexed voter,
        uint voteIndex,
        string message,
        uint timestamp
    );
    event InstallmentDisbursed(
        address indexed campaign,
        uint amount,
        string message,
        uint timestamp
    );
    event CampaignClosed(
        address indexed campaign,
        string message,
        uint timestamp
    );

    constructor(
        string memory _title,
        string memory _desc,
        uint _targetAmt,
        string memory _imgURI,
        string memory _category,
        string memory _country,
        uint _deadline,
        address _owner,
        uint _threshold,
        uint _n1,
        uint _n2
    ) {
        owner = payable(_owner);
        title = _title;
        desc = _desc;
        targetAmt = _targetAmt;
        imgURI = _imgURI;
        category = _category;
        amtraised = 0;
        country = _country;
        deadline = _deadline;
        threshold = (targetAmt * _threshold) / 100;
        votes[0][0] = votes[0][1] = votes[1][0] = votes[1][1] = 0;
        votingInd = 0;
        ind = 0;
        contributorsCount = 0;
        disbursed = 0;
        isCampaignOpen = true;
        targetAchieved = false;
        auditReport = false;
        auditReportCount = 0;
        n1 = _n1;
        n2 = _n2;
    }

    // function modifiers :-
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    // functions :-
    function getContractAddress() public view returns (address) {
        return address(this);
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getOwnerBalance() public view returns (uint) {
        return balances[owner];
    }

    function auditReportSubmitted() public {
        auditReport = true;
        string memory message = auditReportCount == 0
            ? "First Audit Report Submitted"
            : "Second Audit Report Submitted";
        emit AuditReportSubmitted(owner, message, block.timestamp);
        auditReportCount++;
    }

    function contribute() public payable {
        require(isCampaignOpen, "Campaign already closed");
        require(!targetAchieved, "Target already achieved");
        require(block.timestamp <= deadline, "Deadline reached");
        require(
            msg.value + amtraised <= targetAmt,
            "Can't receive more than target"
        );
        require(msg.value > 0, "Contribution amount must be greater than 0");
        if (contribution[msg.sender] == 0) {
            contributors[owner].push(msg.sender);
            contributorsCount++;
        }
        contribution[msg.sender] += msg.value;
        amtraised += msg.value;
        if (amtraised == targetAmt) targetAchieved = true;
        emit ContributionAdded(msg.sender, msg.value, block.timestamp);
    }

    function vote(uint currentVote) public {
        require(isCampaignOpen, "Campaign already closed");
        require(msg.sender != owner, "Owner can't vote");
        require(auditReport, "Audit report not yet submitted");
        require(
            contribution[msg.sender] > threshold,
            "You are not an approver"
        );
        require(!hasVoted[votingInd][msg.sender], "You have already voted");
        string memory message = votingInd == 0
            ? "Second installment vote registered"
            : "Third installment vote registered";
        emit VoteRegistered(msg.sender, votingInd+1, message, block.timestamp);
        votes[votingInd][currentVote]++;
        hasVoted[votingInd][msg.sender] = true;
    }

    function disburse() public payable onlyOwner {
        require(isCampaignOpen, "Campaign already closed");
        require(block.timestamp > deadline, "Deadline not yet reached");
        if (ind == 0) {
            uint reqdContribution = (targetAmt * 70) / 100;
            if (amtraised >= reqdContribution) {
                uint installment1 = (amtraised * n1) / 100;
                uint installment2 = (amtraised * n2) / 100;
                uint installment3 = amtraised - (installment1 + installment2);
                installments[0] = installments[1] = installment1;
                installments[2] = installment3;
                owner.transfer(installments[ind]);
                balances[owner] += installments[ind];
                disbursed += installments[ind];
                amtraised -= installments[ind];
                ind++;
                emit InstallmentDisbursed(
                    getContractAddress(),
                    installments[ind],
                    "First installment disbursed",
                    block.timestamp
                );
            } else reimburse("Disbursable amount not reached");
        } else {
            uint yes = votes[votingInd][0];
            uint tot = votes[votingInd][0] + votes[votingInd][1];
            if (block.timestamp > deadline && !targetAchieved)
                reimburse("Target not achieved till deadline.");
            else if (yes > (tot >> 1)) {
                owner.transfer(installments[ind]);
                balances[owner] += installments[ind];
                disbursed += installments[ind];
                amtraised -= installments[ind];
                string memory message = ind == 1
                    ? "Second installment disbursed"
                    : "Third installment disbursed";
                emit InstallmentDisbursed(
                    getContractAddress(),
                    installments[ind],
                    message,
                    block.timestamp
                );
                ind++;
                if (ind == 3) {
                    isCampaignOpen = false;
                    emit CampaignClosed(
                        getContractAddress(),
                        "Campaign Closed",
                        block.timestamp
                    );
                }
                votingInd++; // this time, voting was succesful, so move on the next index to accomodate next time voting
                auditReport = false;
            } else reimburse("Lack of majority.");
        }
    }

    function reimburse(string memory message) public payable onlyOwner {
        require(isCampaignOpen, "Campaign already closed");
        console.log(message, " Re-imbursement process initiated");
        address payable contributor;
        uint contri;
        for (uint i = 0; i < contributors[owner].length; i++) {
            contributor = payable(contributors[owner][i]);
            contri =
                ((contribution[contributor]) * (targetAmt - disbursed)) /
                targetAmt;
            contribution[contributor] = 0; // Reset contribution to avoid re-entry attack
            contributor.transfer(contri);
        }
        amtraised = 0;
        isCampaignOpen = false;
        emit CampaignClosed(
            getContractAddress(),
            "Campaign Closed",
            block.timestamp
        );
    }
}
