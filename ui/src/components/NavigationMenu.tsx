import React from 'react';
import { Drawer, List, ListItem, ListItemIcon, ListItemText, Box } from '@mui/material';
import RocketLaunchIcon from '@mui/icons-material/RocketLaunch';
import HomeIcon from '@mui/icons-material/Home';
import SettingsIcon from '@mui/icons-material/Settings';
import { useNavigate } from 'react-router-dom';

interface NavigationMenuProps {
  open: boolean;
  onClose: () => void;
}

const NavigationMenu: React.FC<NavigationMenuProps> = ({ open, onClose }) => {
  const navigate = useNavigate();

  const navigateTo = (route: string) => {
    navigate(route);
    onClose(); // Close the menu after navigation
  };

  const listItemStyle: React.CSSProperties = {
    cursor: 'pointer',
  };

  const handleImageClick = () => {
    onClose(); // Close the navigation menu
  };

  return (
    <Drawer anchor="left" open={open} onClose={onClose}>
      <Box
        sx={{
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'space-between',
          height: '100%', // Make the Box take full height of the drawer
        }}
      >
        <List>
          {/* Home */}
          <ListItem style={listItemStyle} onClick={() => navigateTo('/home')}>
            <ListItemIcon>
              <HomeIcon />
            </ListItemIcon>
            <ListItemText primary="Home" />
          </ListItem>

          {/* Cluster Creation */}
          <ListItem style={listItemStyle} onClick={() => navigateTo('/k8s-cluster-creation')}>
            <ListItemIcon>
              <RocketLaunchIcon />
            </ListItemIcon>
            <ListItemText primary="Cluster creation" />
          </ListItem>

          {/* Settings */}
          <ListItem style={listItemStyle} onClick={() => navigateTo('/settings')}>
            <ListItemIcon>
              <SettingsIcon />
            </ListItemIcon>
            <ListItemText primary="Settings" />
          </ListItem>
        </List>

        {/* Add photo at the bottom */}
        <Box
          sx={{
            textAlign: 'center',
            padding: 2,
          }}
        >
          <Box
            component="span"
            onClick={handleImageClick}
            sx={{
              display: 'inline-block',
              maxWidth: '80%',
              margin: '0 auto',
              cursor: 'pointer',
            }}
          >
            CLOSE
          </Box>
        </Box>
      </Box>
    </Drawer>
  );
};

export default NavigationMenu;
